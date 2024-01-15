# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, options, src, lib, flakelight, ... }:
let
  inherit (builtins) attrNames;
  inherit (lib) genAttrs mkIf mkOption subtractLists;
  inherit (lib.types) attrsOf listOf str;
  inherit (flakelight) autoImport;
  inherit (flakelight.types) path;
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
