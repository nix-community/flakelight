# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, genSystems, ... }:
let
  inherit (lib) filterAttrs mapAttrs mkDefault mkIf mkMerge mkOption;
  inherit (lib.types) coercedTo functionTo lazyAttrsOf lines listOf nullOr
    package str submodule;
  inherit (flakelight) supportedSystem;
  inherit (flakelight.types) optFunctionTo packageDef;

  devShellModule.options = {
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

    overrideShell = mkOption {
      type = nullOr packageDef;
      internal = true;
      default = null;
    };
  };
in
{
  options = {
    devShell = mkOption {
      default = null;
      type = nullOr (coercedTo packageDef
        (x: { overrideShell = x; })
        (submodule devShellModule));
    };

    devShells = mkOption {
      type = lazyAttrsOf packageDef;
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.devShell != null) {
      devShells.default = mkDefault ({ pkgs, mkShell }:
        let cfg = mapAttrs (_: v: v pkgs) config.devShell; in
        mkShell.override { inherit (cfg) stdenv; }
          (cfg.env // { inherit (cfg) inputsFrom packages shellHook; }));
    })

    (mkIf (config.devShell.overrideShell or null != null) {
      devShells.default = config.devShell.overrideShell;
    })

    (mkIf (config.devShells != { }) {
      outputs.devShells = genSystems (pkgs:
        filterAttrs (_: supportedSystem pkgs)
          (mapAttrs (_: v: pkgs.callPackage v { }) config.devShells));
    })
  ];
}
