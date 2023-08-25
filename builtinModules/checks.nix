# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, flakelite, ... }:
let
  inherit (lib) isDerivation isFunction mkOption mkIf mapAttrs;
  inherit (lib.types) lazyAttrsOf nullOr raw;
  inherit (flakelite.types) optFunctionTo;

  mkCheck = pkgs: src: name: cmd:
    let
      cmd' = if isFunction cmd then cmd pkgs else cmd;
    in
    if isDerivation cmd' then cmd' else
    pkgs.runCommand "check-${name}" { } ''
      cp --no-preserve=mode -r ${src} src
      cd src
      ${cmd'}
      touch $out
    '';
in
{
  options.checks = mkOption {
    type = nullOr (optFunctionTo (lazyAttrsOf raw));
    default = null;
  };

  config.perSystem = mkIf (config.checks != null) (pkgs: {
    checks = mapAttrs (mkCheck pkgs src) (config.checks pkgs);
  });
}
