# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, flakelite, ... }:
let
  inherit (lib) mkOption mkIf mapAttrsToList;
  inherit (lib.types) lazyAttrsOf nullOr str;
  inherit (flakelite.types) optFunctionTo;
in
{
  options.formatters = mkOption {
    type = nullOr (optFunctionTo (lazyAttrsOf str));
    default = null;
  };

  config = mkIf (config.formatters != null) {
    perSystem = { pkgs, lib, fd, coreutils, ... }: {
      formatter = pkgs.writeShellScriptBin "formatter" ''
        PATH=${lib.makeBinPath (config.devShell.packages pkgs)}
        for f in "$@"; do
          if [ -d "$f" ]; then
            ${fd}/bin/fd "$f" -Htf -x "$0"
          else
            case "$(${coreutils}/bin/basename "$f")" in
              ${toString (mapAttrsToList
                (n: v: "${n}) ${v} \"$f\";;") (config.formatters pkgs))}
            esac
          fi
        done &>/dev/null
      '';
    };

    checks.formatting = { lib, outputs', diffutils, ... }: ''
      ${lib.getExe outputs'.formatter} .
      ${diffutils}/bin/diff -qr ${src} . |\
        sed 's/Files .* and \(.*\) differ/File \1 not formatted/g'
    '';
  };
}
