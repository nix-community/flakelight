# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

# This provides a module that can be added to module systems nested inside of
# flakelight, for example NixOS or home-manager configurations.

{ lib, config, flakelight, moduleArgs, inputs, outputs, ... }:
let
  inherit (lib) mapAttrs mkOption optionalAttrs;
  inherit (flakelight.types) module;
in
{
  options.propagationModule = mkOption { type = module; };

  config.propagationModule =
    { lib, pkgs, options, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
    in
    {
      config = (optionalAttrs (options ? nixpkgs.overlays) {
        # Apply flakelight overlays to NixOS/home-manager configurations
        nixpkgs.overlays = lib.mkOrder 10
          (config.withOverlays ++ [ config.packageOverlay ]);
      })
      // (optionalAttrs (options ? home-manager.sharedModules) {
        # Propagate module to home-manager when using its nixos module
        home-manager.sharedModules = [ config.propagationModule ];
      })
      // {
        # Give access to flakelight module args under `flake` arg.
        # Also include inputs'/outputs' which depend on `pkgs`.
        _module.args.flake = {
          inputs' = mapAttrs (_: mapAttrs (_: v: v.${system} or { })) inputs;
          outputs' = mapAttrs (_: v: v.${system} or { }) outputs;
        } // moduleArgs;
      };
    };
}
