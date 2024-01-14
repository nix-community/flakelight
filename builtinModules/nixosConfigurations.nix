# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, moduleArgs, ... }:
let
  inherit (builtins) concatLists mapAttrs;
  inherit (lib) foldl last mapAttrsToList mkIf mkOption recursiveUpdate
    zipAttrsWith;
  inherit (lib.types) attrs lazyAttrsOf;
  inherit (flakelight.types) optFunctionTo;

  # Avoid checking if toplevel is a derivation as it causes the nixos modules
  # to be evaluated.
  isNixos = x: x ? config.system.build.toplevel;

  mergeCfg = zipAttrsWith (n: vs:
    if n == "specialArgs" then
      foldl (a: b: a // b) { } vs
    else if n == "modules" then
      concatLists vs
    else last vs);

  mkSystem = hostname: cfg:
    let
      inherit (cfg) system;
    in
    inputs.nixpkgs.lib.nixosSystem (mergeCfg [
      {
        specialArgs = {
          inherit inputs hostname;
          inputs' = mapAttrs (_: mapAttrs (_: v: v.${system} or { })) inputs;
        };
        modules = [ config.propagationModule ];
      }
      cfg
    ]);

  systems = mapAttrs
    (hostname: f:
      let val = f moduleArgs; in
      if isNixos val then val else mkSystem hostname val)
    config.nixosConfigurations;
in
{
  options.nixosConfigurations = mkOption {
    type = lazyAttrsOf (optFunctionTo attrs);
    default = { };
  };

  config.outputs = mkIf (config.nixosConfigurations != { }) {
    nixosConfigurations = systems;
    checks = foldl recursiveUpdate { } (mapAttrsToList
      (n: v: {
        ${v.config.nixpkgs.system}."nixos-${n}" = v.pkgs.runCommand
          "check-nixos-${n}"
          { } "echo ${v.config.system.build.toplevel} > $out";
      })
      systems);
  };
}
