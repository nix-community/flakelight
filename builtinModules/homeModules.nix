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
    homeModule = mkOption {
      type = nullOr module;
      default = null;
    };

    homeModules = mkOption {
      type = lazyAttrsOf module;
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.homeModule != null) {
      homeModules.default = config.homeModule;
    })

    (mkIf (config.homeModules != { }) {
      outputs = { inherit (config) homeModules; };
    })
  ];
}
