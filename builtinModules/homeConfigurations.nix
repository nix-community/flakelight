# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, autoloadArgs, ... }:
let
  inherit (builtins) isAttrs mapAttrs;
  inherit (lib) foldl mapAttrsToList mergeOneOption mkOption mkOptionType mkIf
    recursiveUpdate;
  inherit (lib.types) lazyAttrsOf;
  inherit (flakelight.types) optFunctionTo;

  homeConfiguration = mkOptionType {
    name = "homeConfiguration";
    description = "homeConfiguration";
    descriptionClass = "noun";
    check = x: isAttrs x && x ? activationPackage;
    merge = mergeOneOption;
  };

  configs = mapAttrs (_: f: f autoloadArgs) config.homeConfigurations;
in
{
  options.homeConfigurations = mkOption {
    type = lazyAttrsOf (optFunctionTo homeConfiguration);
    default = { };
  };

  config.outputs = mkIf (config.homeConfigurations != { }) {
    homeConfigurations = configs;
    checks = foldl recursiveUpdate { } (mapAttrsToList
      (n: v: {
        ${v.config.nixpkgs.system}."home-${n}" = v.activationPackage;
      })
      configs);
  };
}
