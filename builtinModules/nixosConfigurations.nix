# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, moduleArgs, ... }:
let
  inherit (builtins) mapAttrs;
  inherit (lib) foldl mapAttrsToList mkIf mkOption recursiveUpdate;
  inherit (lib.types) attrs lazyAttrsOf;
  inherit (flakelight) selectAttr;
  inherit (flakelight.types) optFunctionTo;

  # Avoid checking if toplevel is a derivation as it causes the nixos modules
  # to be evaluated.
  isNixos = x: x ? config.system.build.toplevel;

  mkNixos = hostname: cfg: inputs.nixpkgs.lib.nixosSystem (cfg // {
    specialArgs = {
      inherit inputs hostname;
      inputs' = mapAttrs (_: selectAttr cfg.system) inputs;
    } // cfg.specialArgs or { };
    modules = [ config.propagationModule ] ++ cfg.modules or [ ];
  });

  configs = mapAttrs
    (hostname: f:
      let val = f moduleArgs; in
      if isNixos val then val else mkNixos hostname val)
    config.nixosConfigurations;
in
{
  options.nixosConfigurations = mkOption {
    type = lazyAttrsOf (optFunctionTo attrs);
    default = { };
  };

  config.outputs = mkIf (config.nixosConfigurations != { }) {
    nixosConfigurations = configs;
    checks = foldl recursiveUpdate { } (mapAttrsToList
      (n: v: {
        # Wrapping the drv is needed as computing its name is expensive
        # If not wrapped, it slows down `nix flake show` significantly
        ${v.config.nixpkgs.system}."nixos-${n}" = v.pkgs.runCommand
          "check-nixos-${n}"
          { } "echo ${v.config.system.build.toplevel} > $out";
      })
      configs);
  };
}
