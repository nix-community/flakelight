# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, moduleArgs, ... }:
let
  inherit (lib) mkMerge mkOption mkIf;
  inherit (lib.types) lazyAttrsOf;
  inherit (flakelight.types) nullable optCallWith overlay;
in
{
  options = {
    overlay = mkOption {
      type = nullable overlay;
      default = null;
    };

    overlays = mkOption {
      type = optCallWith moduleArgs (lazyAttrsOf overlay);
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.overlay != null) {
      overlays.default = config.overlay;
    })

    (mkIf (config.overlays != { }) {
      outputs = { inherit (config) overlays; };
    })
  ];
}
