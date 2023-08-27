# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (builtins) isAttrs;
  inherit (lib) foldl mapAttrsToList mergeOneOption mkOption mkOptionType mkIf
    recursiveUpdate;
  inherit (lib.types) lazyAttrsOf;

  homeConfiguration = mkOptionType {
    name = "homeConfiguration";
    description = "homeConfiguration";
    descriptionClass = "noun";
    check = x: isAttrs x && x ? activationPackage;
    merge = mergeOneOption;
  };
in
{
  options.homeConfigurations = mkOption {
    type = lazyAttrsOf homeConfiguration;
    default = { };
  };

  config.outputs = mkIf (config.homeConfigurations != { }) {
    inherit (config) homeConfigurations;
    checks = foldl recursiveUpdate { } (mapAttrsToList
      (n: v: {
        ${v.config.nixpkgs.system}."home-${n}" = v.activationPackage;
      })
      config.homeConfigurations);
  };
}
