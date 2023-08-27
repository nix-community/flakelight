# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) lazyAttrsOf;
  inherit (flakelight.types) overlay;
in
{
  options.overlays = mkOption {
    type = lazyAttrsOf overlay;
    default = { };
  };

  config.outputs = mkIf (config.overlays != { }) { inherit (config) overlays; };
}
