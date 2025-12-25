# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, moduleArgs, pkgsFor, ... }:
let
  inherit (builtins) mapAttrs;
  inherit (lib) mapAttrsToList mkIf mkMerge mkOption;
  inherit (lib.types) attrs lazyAttrsOf;
  inherit (flakelight.types) optCallWith;

  # Avoid checking if toplevel is a derivation as it causes the nixos modules
  # to be evaluated.
  isNixos = x: x ? config.system.build.toplevel;

  mkNixos = hostname: cfg: inputs.nixpkgs.lib.nixosSystem (cfg // {
    specialArgs = {
      inherit inputs hostname;
    } // cfg.specialArgs or { };
    modules = [
      config.propagationModule
      ({ flake, ... }: { _module.args = { inherit (flake) inputs'; }; })
    ] ++ cfg.modules or [ ];
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

      outputs.checks = mkMerge (mapAttrsToList
        (n: v:
          let inherit (v.pkgs.stdenv.buildPlatform) system; in
          {
            # Wrapping the drv is needed as computing its name is expensive
            # If not wrapped, it slows down `nix flake show` significantly
            ${system}."nixos-${n}" =
              pkgsFor.${system}.runCommand "check-nixos-${n}" { }
                "echo ${v.config.system.build.toplevel} > $out";
          })
        configs);
    })

    { nixDirAliases.nixosConfigurations = [ "nixos" ]; }
  ];
}
