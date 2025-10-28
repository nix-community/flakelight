# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, inputs, lib, flakelight, moduleArgs, ... }:
let
  inherit (builtins) all attrNames head isAttrs length;
  inherit (lib) foldAttrs functionArgs genAttrs getFiles getValues isFunction
    mapAttrs mergeAttrs mkOption mkOptionType showFiles showOption
    subtractLists;
  inherit (lib.types) coercedTo functionTo lazyAttrsOf listOf nonEmptyStr raw
    uniq;
  inherit (flakelight.types) function optCallWith overlay path;

  outputs = mkOptionType {
    name = "outputs";
    description = "output values";
    descriptionClass = "noun";
    merge = loc: defs:
      if (length defs) == 1 then (head defs).value
      else if all isAttrs (getValues defs) then
        (lazyAttrsOf outputs).merge loc defs
      else
        throw ("The option `${showOption loc}' has conflicting definitions" +
          " in ${showFiles (getFiles defs)}");
  };

  applyPatches = system: inputs.nixpkgs.legacyPackages.${system}.applyPatches;

  patchedNixpkgs = system: applyPatches system {
    src = inputs.nixpkgs;
    name = "nixpkgs-patched";
    inherit (config.nixpkgs) patches;
  };

  patchedNixpkgs' = system:
    if config.nixpkgs.patches == [ ]
    then inputs.nixpkgs else patchedNixpkgs system;

  pkgsFor = genAttrs config.systems (system: import (patchedNixpkgs' system) {
    inherit (config.nixpkgs) config;
    localSystem = { inherit system; };
    overlays = config.nixpkgs.overlays ++ [ config.packageOverlay ];
  });

  genSystems = f: genAttrs config.systems (system: f pkgsFor.${system});

  funcToOverlayList = f:
    let
      fArgs = attrNames (functionArgs f);
      mArgs = attrNames moduleArgs;
      fApplied = f moduleArgs;
      isOverlay = (subtractLists mArgs fArgs != [ ])
        || isFunction fApplied;
    in
    if isOverlay then [ f ] else fApplied;

  withOverlaysType = coercedTo function funcToOverlayList (listOf overlay);
in
{
  options = {
    inputs = mkOption {
      type = lazyAttrsOf raw;
    };

    systems = mkOption {
      type = uniq (listOf nonEmptyStr);
      default = [ "x86_64-linux" "aarch64-linux" ];
    };

    outputs = mkOption {
      type = optCallWith moduleArgs (lazyAttrsOf outputs);
      default = { };
    };

    perSystem = mkOption {
      type = functionTo (lazyAttrsOf outputs);
      default = _: { };
    };

    nixpkgs = {
      config = mkOption {
        type = lazyAttrsOf raw;
        default = { };
      };

      overlays = mkOption {
        type = listOf overlay;
        default = [ ];
      };

      patches = mkOption {
        type = listOf path;
        default = [ ];
      };
    };

    withOverlays = mkOption {
      type = withOverlaysType;
      default = [ ];
    };
  };

  config = {
    _module.args = {
      inherit (config) inputs outputs;
      inherit pkgsFor genSystems;
    };

    nixpkgs.overlays = config.withOverlays;

    outputs = foldAttrs mergeAttrs { } (map
      (system: mapAttrs
        (_: v: { ${system} = v; })
        (config.perSystem pkgsFor.${system}))
      config.systems);
  };
}
