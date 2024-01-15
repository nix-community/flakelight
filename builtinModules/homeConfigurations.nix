# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, moduleArgs, ... }:
let
  inherit (builtins) head mapAttrs match;
  inherit (lib) foldl mapAttrsToList mkOption mkIf recursiveUpdate;
  inherit (lib.types) attrs lazyAttrsOf;
  inherit (flakelight) selectAttr;
  inherit (flakelight.types) optCallWith;

  isHome = x: x ? activationPackage;

  mkHome = name: cfg: inputs.home-manager.lib.homeManagerConfiguration (
    (removeAttrs cfg [ "system" ]) // {
      extraSpecialArgs = {
        inherit inputs;
        inputs' = mapAttrs (_: selectAttr cfg.system) inputs;
      } // cfg.extraSpecialArgs or { };
      modules = [
        ({ lib, ... }: {
          home.username = lib.mkDefault (head (match "([^@]*)(@.*)?" name));
        })
        config.propagationModule
      ] ++ cfg.modules or [ ];
      pkgs = inputs.nixpkgs.legacyPackages.${cfg.system};
    }
  );

  configs = mapAttrs
    (name: cfg: if isHome cfg then cfg else mkHome name cfg)
    config.homeConfigurations;
in
{
  options.homeConfigurations = mkOption {
    type = optCallWith moduleArgs (lazyAttrsOf (optCallWith moduleArgs attrs));
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
