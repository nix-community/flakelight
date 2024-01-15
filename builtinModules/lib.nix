# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, moduleArgs, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) attrsOf raw;
  inherit (flakelight.types) optCallWith;
in
{
  options.lib = mkOption {
    type = optCallWith moduleArgs (attrsOf raw);
    default = { };
  };

  config.outputs = mkIf (config.lib != { }) {
    inherit (config) lib;
  };
}
