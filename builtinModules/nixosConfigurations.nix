# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (builtins) isAttrs;
  inherit (lib) foldl mapAttrsToList mergeOneOption mkIf mkOption mkOptionType
    recursiveUpdate;
  inherit (lib.types) lazyAttrsOf;

  nixosConfiguration = mkOptionType {
    name = "nixosConfiguration";
    description = "nixosConfiguration";
    descriptionClass = "noun";
    check = x: isAttrs x
      && x ? config.nixpkgs.system
      && x ? config.system.build.toplevel;
    merge = mergeOneOption;
  };
in
{
  options.nixosConfigurations = mkOption {
    type = lazyAttrsOf nixosConfiguration;
    default = { };
  };

  config.outputs = mkIf (config.nixosConfigurations != { }) {
    inherit (config) nixosConfigurations;
    checks = foldl recursiveUpdate { } (mapAttrsToList
      (n: v: {
        ${v.config.nixpkgs.system}."nixos-${n}" =
          v.config.system.build.toplevel;
      })
      config.nixosConfigurations);
  };
}
