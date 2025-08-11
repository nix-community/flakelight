# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, options, src, lib, flakelight, ... }:
let
  inherit (builtins) attrNames elem;
  inherit (lib) findFirst genAttrs mkIf mkOption pathExists subtractLists;
  inherit (lib.types) attrsOf listOf str;
  inherit (flakelight) importDir importDirPaths;
  inherit (flakelight.types) path;

  inherit (config) nixDir;

  importName = asPaths: name:
    if pathExists (nixDir + "/${name}.nix")
    then { success = true; value = import (nixDir + "/${name}.nix"); }
    else if pathExists (nixDir + "/${name}/default.nix")
    then { success = true; value = import (nixDir + "/${name}"); }
    else if pathExists (nixDir + "/${name}")
    then {
      success = true;
      value = (if asPaths then importDirPaths else importDir)
        (nixDir + "/${name}");
    }
    else { success = false; };

  importNames = asPaths: names:
    findFirst (x: x.success) { success = false; }
      (map (importName asPaths) names);
in
{
  options = {
    nixDir = mkOption {
      type = path;
      default = src + /nix;
    };

    nixDirAliases = mkOption {
      type = attrsOf (listOf str);
      default = { };
    };

    nixDirPathAttrs = mkOption {
      type = listOf str;
      default = [ ];
    };
  };

  config = genAttrs (subtractLists [ "_module" "nixDir" ] (attrNames options))
    (name:
      let
        internal = options.${name}.internal or false;
        val = importNames
          (!(elem name [ "nixDirPathAttrs" "nixDirAliases" ])
            && (elem name config.nixDirPathAttrs))
          (if name == "nixDirAliases" then [ name ] else
          ([ name ] ++ config.nixDirAliases.${name} or [ ]));
        cond = !internal && val.success;
      in
      mkIf cond (if cond then val.value else { }));
}
