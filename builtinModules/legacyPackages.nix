# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, genSystems, ... }:
let
  inherit (lib) mkIf mkOption;
  inherit (lib.types) functionTo nullOr pkgs;
in
{
  options.legacyPackages = mkOption {
    type = nullOr (functionTo pkgs);
    default = null;
  };

  config.outputs = mkIf (config.legacyPackages != null) {
    legacyPackages = genSystems config.legacyPackages;
  };
}
