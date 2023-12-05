# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) filterAttrs mapAttrs mkDefault mkIf mkMerge mkOption;
  inherit (lib.types) functionTo lazyAttrsOf lines listOf nullOr package str
    submodule;
  inherit (flakelight) supportedSystem;
  inherit (flakelight.types) optFunctionTo packageDef;
in
{
  options = {
    devShell = mkOption {
      default = null;
      type = nullOr (submodule {
        options = {
          inputsFrom = mkOption {
            type = functionTo (listOf package);
            default = _: [ ];
          };

          packages = mkOption {
            type = functionTo (listOf package);
            default = _: [ ];
          };

          shellHook = mkOption {
            type = optFunctionTo lines;
            default = "";
          };

          env = mkOption {
            type = optFunctionTo (lazyAttrsOf str);
            default = { };
          };

          stdenv = mkOption {
            type = functionTo package;
            default = pkgs: pkgs.stdenv;
          };
        };
      });
    };

    devShells = mkOption {
      type = lazyAttrsOf packageDef;
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.devShell != null) {
      devShells.default = mkDefault ({ pkgs, mkShell }:
        mkShell.override { stdenv = config.devShell.stdenv pkgs; }
          ((config.devShell.env pkgs) // {
            inputsFrom = config.devShell.inputsFrom pkgs;
            packages = config.devShell.packages pkgs;
            shellHook = config.devShell.shellHook pkgs;
          }));
    })

    (mkIf (config.devShells != { }) {
      perSystem = pkgs: {
        devShells = filterAttrs (_: supportedSystem pkgs)
          (mapAttrs (_: v: pkgs.callPackage v { }) config.devShells);
      };
    })
  ];
}
