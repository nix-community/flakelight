# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, genSystems, moduleArgs, ... }:
let
  inherit (lib) filterAttrs functionArgs mapAttrs mkDefault mkIf mkMerge
    mkOption;
  inherit (lib.types) attrs coercedTo functionTo lazyAttrsOf lines listOf
    package str submodule;
  inherit (flakelight) supportedSystem;
  inherit (flakelight.types) function nullable optCallWith optFunctionTo
    packageDef;

  devShellModule.options = {
    inputsFrom = mkOption {
      type = optFunctionTo (listOf package);
      default = [ ];
    };

    packages = mkOption {
      type = optFunctionTo (listOf package);
      default = [ ];
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
      type = optFunctionTo package;
      default = pkgs: pkgs.stdenv;
    };

    overrideShell = mkOption {
      type = nullable packageDef;
      internal = true;
      default = null;
    };
  };

  wrapFn = fn: pkgs:
    if (functionArgs fn == { }) || !(package.check (pkgs.callPackage fn { }))
    then fn pkgs
    else { overrideShell = fn; };
in
{
  options = {
    devShell = mkOption {
      default = null;
      type = nullable (coercedTo function wrapFn
        (coercedTo attrs (x: _: x)
          (functionTo (submodule devShellModule))));
    };

    devShells = mkOption {
      type = optCallWith moduleArgs (lazyAttrsOf packageDef);
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.devShell != null) {
      devShells.default = mkDefault ({ pkgs, mkShell }:
        let cfg = mapAttrs (_: v: v pkgs) (config.devShell pkgs); in
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
