# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) attrsOf raw;
in
{
  options.lib = mkOption {
    type = attrsOf raw;
    default = { };
  };

  config.outputs = mkIf (config.lib != { }) {
    inherit (config) lib;
  };
}
