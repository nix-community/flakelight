# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) mkMerge mkOption mkIf;
  inherit (lib.types) functionTo lazyAttrsOf nullOr package uniq;
  inherit (flakelight.types) optFunctionTo;

  bundler = uniq (functionTo package);
in
{
  options = {
    bundler = mkOption {
      type = nullOr bundler;
      default = null;
    };

    bundlers = mkOption {
      type = nullOr (optFunctionTo (lazyAttrsOf bundler));
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.bundler != null) {
      bundlers.default = config.bundler;
    })

    (mkIf (config.bundlers != null) {
      perSystem = pkgs: {
        bundlers = config.bundlers pkgs;
      };
    })
  ];
}
