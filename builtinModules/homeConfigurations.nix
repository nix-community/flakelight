# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, moduleArgs, ... }:
let
  inherit (builtins) concatLists head mapAttrs match;
  inherit (lib) foldl last mapAttrsToList mkOption mkIf recursiveUpdate
    zipAttrsWith;
  inherit (lib.types) attrs lazyAttrsOf;
  inherit (flakelight.types) optFunctionTo;

  isHome = x: x ? activationPackage;

  mergeCfg = zipAttrsWith (n: vs:
    if n == "extraSpecialArgs" then
      foldl (a: b: a // b) { } vs
    else if n == "modules" then
      concatLists vs
    else last vs);

  mkHome = name: cfg:
    let
      inherit (cfg) system;
    in
    inputs.home-manager.lib.homeManagerConfiguration (mergeCfg [
      {
        extraSpecialArgs = {
          inherit inputs;
          inputs' = mapAttrs (_: mapAttrs (_: v: v.${system} or { })) inputs;
        };
        modules = [
          ({ lib, ... }: {
            home.username = lib.mkDefault (head (match "([^@]*)(@.*)?" name));
          })
          config.propagationModule
        ];
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      }
      (removeAttrs cfg [ "system" ])
    ]);

  configs = mapAttrs
    (name: f:
      let val = f moduleArgs; in
      if isHome val then val else mkHome name val)
    config.homeConfigurations;
in
{
  options.homeConfigurations = mkOption {
    type = lazyAttrsOf (optFunctionTo attrs);
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
