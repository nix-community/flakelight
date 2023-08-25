# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelite, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) lazyAttrsOf;
  inherit (flakelite.types) overlay;
in
{
  options.overlays = mkOption {
    type = lazyAttrsOf overlay;
    default = { };
  };

  config.outputs = mkIf (config.overlays != { }) { inherit (config) overlays; };
}
