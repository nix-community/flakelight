# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, genSystems, ... }:
let
  inherit (lib) mkIf mkOption;
  inherit (lib.types) functionTo pkgs;
  inherit (flakelight.types) nullable;
in
{
  options.legacyPackages = mkOption {
    type = nullable (functionTo pkgs);
    default = null;
  };

  config.outputs = mkIf (config.legacyPackages != null) {
    legacyPackages = genSystems config.legacyPackages;
  };
}
