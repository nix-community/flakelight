# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, inputs, outputs, flakelite, ... }:
let
  inherit (lib) isList mkOption mkOrder mapAttrs optionalAttrs;
  inherit (lib.types) listOf nullOr oneOf str;
in
{
  options = {
    description = mkOption {
      type = nullOr str;
      default = null;
    };

    license = mkOption {
      type = nullOr (oneOf [ str (listOf str) ]);
      default = null;
    };
  };

  config.withOverlays = mkOrder 10 (final: prev:
    let
      system = prev.stdenv.hostPlatform.system;
    in
    {
      inherit src inputs outputs flakelite system;
      inputs' = mapAttrs (_: mapAttrs (_: v: v.${system} or { })) inputs;
      outputs' = mapAttrs (_: v: v.${system} or { }) outputs;

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
