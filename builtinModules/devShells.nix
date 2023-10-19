# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) any attrValues filterAttrs mapAttrs mkDefault mkIf mkMerge
    mkOption optionalAttrs;
  inherit (lib.types) lazyAttrsOf functionTo lines listOf nullOr package str;
  inherit (flakelight) supportedSystem;
  inherit (flakelight.types) optFunctionTo packageDef;
in
{
  options = {
    devShell = {
      inputsFrom = mkOption {
        type = nullOr
          (functionTo (listOf package));
        default = null;
      };

      packages = mkOption {
        type = nullOr
          (functionTo (listOf package));
        default = null;
      };

      shellHook = mkOption {
        type = nullOr (optFunctionTo lines);
        default = null;
      };

      env = mkOption {
        type = nullOr
          (optFunctionTo (lazyAttrsOf str));
        default = null;
      };
    };

    devShells = mkOption {
      type = lazyAttrsOf packageDef;
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (any (x: x != null) (attrValues config.devShell)) {
      devShells.default = mkDefault ({ pkgs, mkShell }: mkShell (
        optionalAttrs (config.devShell.env != null)
          (config.devShell.env pkgs)
        // optionalAttrs (config.devShell.inputsFrom != null) {
          inputsFrom = config.devShell.inputsFrom pkgs;
        }
        // optionalAttrs (config.devShell.packages != null) {
          packages = config.devShell.packages pkgs;
        }
        // optionalAttrs (config.devShell.shellHook != null) {
          shellHook = config.devShell.shellHook pkgs;
        }
      ));
    })

    (mkIf (config.devShells != { }) {
      perSystem = pkgs: {
        devShells = filterAttrs (_: supportedSystem pkgs)
          (mapAttrs (_: v: pkgs.callPackage v { }) config.devShells);
      };
    })
  ];
}
