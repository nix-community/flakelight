# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, moduleArgs, ... }:
let
  inherit (builtins) mapAttrs;
  inherit (lib) mapAttrsToList mkIf mkMerge mkOption;
  inherit (lib.types) attrs lazyAttrsOf;
  inherit (flakelight) selectAttr;
  inherit (flakelight.types) optCallWith;

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
    (hostname: cfg: if isNixos cfg then cfg else mkNixos hostname cfg)
    config.nixosConfigurations;
in
{
  options.nixosConfigurations = mkOption {
    type = optCallWith moduleArgs (lazyAttrsOf (optCallWith moduleArgs attrs));
    default = { };
  };

  config = mkMerge [
    (mkIf (config.nixosConfigurations != { }) {
      outputs.nixosConfigurations = configs;

      checks = pkgs: mkMerge (mapAttrsToList
        (n: v: mkIf (pkgs.system == v.config.nixpkgs.system) {
          # Wrapping the drv is needed as computing its name is expensive
          # If not wrapped, it slows down `nix flake show` significantly
          "nixos-${n}" = pkgs.runCommand "check-nixos-${n}" { }
            "echo ${v.config.system.build.toplevel} > $out";
        })
        configs);
    })

    { nixDirAliases.nixosConfigurations = [ "nixos" ]; }
  ];
}
