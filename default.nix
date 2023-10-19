# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

nixpkgs:
let
  inherit (builtins) isAttrs isPath readDir;
  inherit (nixpkgs.lib) attrNames composeManyExtensions
    filter findFirst fix genAttrs getValues hasSuffix isFunction isList
    mapAttrsToList pathExists pipe removePrefix removeSuffix evalModules
    mkDefault mkOptionType singleton;
  inherit (nixpkgs.lib.types) coercedTo functionTo listOf;
  inherit (nixpkgs.lib.options) mergeEqualOption mergeOneOption;

  builtinModules = mapAttrsToList (k: _: ./builtinModules + ("/" + k))
    (readDir ./builtinModules);

  mkFlake = {
    __functor = self: src: root: (evalModules {
      specialArgs.modulesPath = ./builtinModules;
      modules = builtinModules ++ self.extraModules ++ [
        { inputs.nixpkgs = mkDefault nixpkgs; }
        { _module.args = { inherit src flakelight; }; }
        root
      ];
    }).config.outputs;

    # Attributes to allow module flakes to extend mkFlake
    extraModules = [ ];
    extend = (fix (extend': mkFlake': modules: fix (self: mkFlake' // {
      extraModules = mkFlake'.extraModules ++ modules;
      extend = extend' self;
    }))) mkFlake;
  };

  flakelight = {
    inherit mkFlake supportedSystem autoImport autoImportArgs;

    types = {
      overlay = mkOptionType {
        name = "overlay";
        description = "nixpkgs overlay";
        descriptionClass = "noun";
        check = isFunction;
        merge = _: defs: composeManyExtensions (getValues defs);
      };

      packageDef = mkOptionType {
        name = "packageDef";
        description = "package definition";
        descriptionClass = "noun";
        check = isFunction;
        merge = mergeOneOption;
      };

      path = mkOptionType {
        name = "path";
        description = "path";
        descriptionClass = "noun";
        check = isPath;
        merge = mergeEqualOption;
      };

      module = mkOptionType {
        name = "module";
        description = "module";
        descriptionClass = "noun";
        check = x: isPath x || isFunction x || isAttrs x;
        merge = _: defs: { imports = getValues defs; };
      };

      optListOf = elemType: coercedTo elemType singleton (listOf elemType);

      optFunctionTo = elemType: coercedTo elemType (x: _: x)
        (functionTo elemType);
    };
  };

  supportedSystem = { lib, stdenv, ... }:
    lib.meta.availableOn stdenv.hostPlatform;

  importDir = path: genAttrs
    (pipe (readDir path) [
      attrNames
      (filter (s: s != "default.nix"))
      (filter (hasSuffix ".nix"))
      (map (removeSuffix ".nix"))
      (map (removePrefix "_"))
    ])
    (p: import (path + (if pathExists
      (path + "/_${p}.nix") then "/_${p}.nix" else "/${p}.nix")));

  autoImport = dir: name:
    if isList name
    then findFirst (x: x != null) null (map (autoImport dir) name)
    else
      if pathExists (dir + "/${name}.nix")
      then import (dir + "/${name}.nix")
      else if pathExists (dir + "/${name}/default.nix")
      then import (dir + "/${name}")
      else if pathExists (dir + "/${name}")
      then importDir (dir + "/${name}")
      else null;

  autoImportArgs = dir: args: name:
    let v = autoImport dir name; in
    if isFunction v then v args else v;
in
flakelight
