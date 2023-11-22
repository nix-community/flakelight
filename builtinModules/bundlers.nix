# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) isFunction mapAttrs mkMerge mkOption mkIf;
  inherit (lib.types) lazyAttrsOf nullOr;
  inherit (flakelight.types) function optFunctionTo;

  wrapBundler = pkgs: bundler: drv:
    if isFunction (bundler (pkgs // drv)) then bundler pkgs drv else bundler drv;
in
{
  options = {
    bundler = mkOption {
      type = nullOr function;
      default = null;
    };

    bundlers = mkOption {
      type = nullOr (optFunctionTo (lazyAttrsOf function));
      default = null;
    };
  };

  config = mkMerge [
    (mkIf (config.bundler != null) {
      bundlers.default = config.bundler;
    })

    (mkIf (config.bundlers != null) {
      perSystem = pkgs: {
        bundlers = mapAttrs (_: wrapBundler pkgs) (config.bundlers pkgs);
      };
    })
  ];
}
