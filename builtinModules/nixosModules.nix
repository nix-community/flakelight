# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, moduleArgs, ... }:
let
  inherit (lib) mkOption mkIf mkMerge;
  inherit (lib.types) lazyAttrsOf;
  inherit (flakelight.types) module nullable optCallWith;
in
{
  options = {
    nixosModule = mkOption {
      type = nullable module;
      default = null;
    };

    nixosModules = mkOption {
      type = optCallWith moduleArgs (lazyAttrsOf module);
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.nixosModule != null) {
      nixosModules.default = config.nixosModule;
    })

    (mkIf (config.nixosModules != { }) {
      outputs = { inherit (config) nixosModules; };
    })

    { nixDirPathAttrs = [ "nixosModules" ]; }
  ];
}
