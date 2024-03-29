# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, inputs, outputs, flakelight, moduleArgs, ... }:
let
  inherit (lib) isList mkOption mkOrder mapAttrs optionalAttrs;
  inherit (lib.types) listOf oneOf str;
  inherit (builtins) pathExists;
  inherit (flakelight) selectAttr;
  inherit (flakelight.types) nullable;
in
{
  options = {
    description = mkOption {
      type = nullable str;
      default =
        if pathExists (src + /flake.nix)
        then (import (src + /flake.nix)).description or null
        else null;
    };

    license = mkOption {
      type = nullable (oneOf [ str (listOf str) ]);
      default = null;
    };
  };

  config.withOverlays = mkOrder 10 (final: prev:
    let inherit (prev.stdenv.hostPlatform) system; in {
      inherit system moduleArgs src inputs outputs flakelight;
      inputs' = mapAttrs (_: selectAttr system) inputs;
      outputs' = selectAttr system outputs;

      defaultMeta = {
        platforms = config.systems;
      } // optionalAttrs (config.description != null) {
        inherit (config) description;
      } // optionalAttrs (config.license != null) {
        license =
          let
            getLicense = license: final.lib.licenses.${license} or
              (final.lib.meta.getLicenseFromSpdxId license);
          in
          if isList config.license then map getLicense config.license
          else getLicense config.license;
      };
    });
}
