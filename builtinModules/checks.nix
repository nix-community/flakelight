# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, flakelight, genSystems, ... }:
let
  inherit (lib) isDerivation isFunction mkOption mkIf mapAttrs;
  inherit (lib.types) lazyAttrsOf nullOr raw;
  inherit (flakelight.types) optFunctionTo;

  mkCheck = pkgs: name: cmd:
    let cmd' = if isFunction cmd then cmd pkgs else cmd; in
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

  config.outputs = mkIf (config.checks != null) {
    checks = genSystems (pkgs:
      mapAttrs (mkCheck pkgs) (config.checks pkgs));
  };
}
