# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) mkMerge mkOption mkIf;
  inherit (lib.types) lazyAttrsOf nullOr;
  inherit (flakelight.types) overlay;
in
{
  options = {
    overlay = mkOption {
      type = nullOr overlay;
      default = null;
    };

    overlays = mkOption {
      type = lazyAttrsOf overlay;
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
