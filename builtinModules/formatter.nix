# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, flakelight, genSystems, ... }:
let
  inherit (lib) mkDefault mkMerge mkOption mkIf mapAttrsToList;
  inherit (lib.types) functionTo lazyAttrsOf nullOr package str;
  inherit (flakelight.types) optFunctionTo;
in
{
  options = {
    formatter = mkOption {
      type = nullOr (functionTo package);
      default = null;
    };
    formatters = mkOption {
      type = nullOr (optFunctionTo (lazyAttrsOf str));
      default = null;
    };
  };

  config = mkMerge [
    (mkIf (config.formatter != null) {
      outputs.formatter = genSystems config.formatter;
    })

    (mkIf (config.formatters != null) {
      outputs.formatter = mkDefault (genSystems
        ({ pkgs, lib, fd, coreutils, ... }:
          pkgs.writeShellScriptBin "formatter" ''
            PATH=${lib.makeBinPath (config.devShell.packages or (_: [ ]) pkgs)}
            for f in "$@"; do
              if [ -d "$f" ]; then
                ${fd}/bin/fd "$f" -Htf -x "$0" &
              else
                case "$(${coreutils}/bin/basename "$f")" in
                  ${toString (mapAttrsToList
                    (n: v: "${n}) ${v} \"$f\" & ;;") (config.formatters pkgs))}
                esac
              fi
            done &>/dev/null
            wait
          ''));
    })

    (mkIf ((config.formatters != null) || (config.formatter != null)) {
      checks.formatting = { lib, outputs', diffutils, ... }: ''
        ${lib.getExe outputs'.formatter} .
        ${diffutils}/bin/diff -qr ${src} . |\
          sed 's/Files .* and \(.*\) differ/File \1 not formatted/g'
      '';
    })
  ];
}
