# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, options, src, lib, flakelight, ... }:
let
  inherit (builtins) attrNames;
  inherit (lib) findFirst genAttrs isList mkIf mkOption pathExists
    subtractLists;
  inherit (lib.types) attrsOf listOf str;
  inherit (flakelight) importDir;
  inherit (flakelight.types) path;

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
  };

  config = genAttrs (subtractLists [ "_module" "nixDir" ] (attrNames options))
    (name:
      let
        internal = options.${name}.internal or false;
        val = autoImport config.nixDir
          (if name == "nixDirAliases" then name else
          ([ name ] ++ config.nixDirAliases.${name} or [ ]));
        cond = !internal && (val != null);
      in
      mkIf cond (if cond then val else { }));
}
