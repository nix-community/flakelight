# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

# This provides a module that can be added to module systems nested inside of
# flakelight, for example NixOS or home-manager configurations.

{ lib, config, flakelight, moduleArgs, inputs, outputs, ... }:
let
  inherit (lib) mapAttrs mkOption optionalAttrs;
  inherit (flakelight) selectAttr;
  inherit (flakelight.types) module;
in
{
  options.propagationModule = mkOption { type = module; internal = true; };

  config.propagationModule =
    { lib, pkgs, options, ... }:
    let inherit (pkgs.stdenv.hostPlatform) system; in {
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
          inputs' = mapAttrs (_: selectAttr system) inputs;
          outputs' = selectAttr system outputs;
        } // moduleArgs;
      };
    };
}
