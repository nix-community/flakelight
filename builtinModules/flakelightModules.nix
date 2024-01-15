# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, moduleArgs, ... }:
let
  inherit (lib) mkOption mkIf mkMerge;
  inherit (lib.types) lazyAttrsOf nullOr;
  inherit (flakelight.types) module optCallWith;
in
{
  options = {
    flakelightModule = mkOption {
      type = nullOr module;
      default = null;
    };

    flakelightModules = mkOption {
      type = optCallWith moduleArgs (lazyAttrsOf module);
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.flakelightModule != null) {
      flakelightModules.default = config.flakelightModule;
    })

    (mkIf (config.flakelightModules != { }) {
      outputs = { inherit (config) flakelightModules; };
    })
  ];
}
