# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelite, ... }:
let
  inherit (lib) mkOption mkIf mkMerge;
  inherit (lib.types) lazyAttrsOf nullOr;
  inherit (flakelite.types) module;
in
{
  options = {
    nixosModule = mkOption {
      type = nullOr module;
      default = null;
    };

    nixosModules = mkOption {
      type = lazyAttrsOf module;
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
  ];
}
