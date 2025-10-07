# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, options, src, lib, flakelight, ... }:
let
  inherit (builtins) attrNames elem;
  inherit (lib) attrValues concatMap genAttrs mkMerge mkOption pathExists
    subtractLists;
  inherit (lib.types) attrsOf listOf str;
  inherit (flakelight) importDir importDirPaths;
  inherit (flakelight.types) nullable path;

  inherit (config) nixDir;

  importName = asPaths: type: name:
    if pathExists (nixDir + "/${name}.nix")
    then [ (import (nixDir + "/${name}.nix")) ]
    else if pathExists (nixDir + "/${name}/default.nix")
    then [ (import (nixDir + "/${name}")) ]
    else if pathExists (nixDir + "/${name}")
    then
      let
        asAttrs = (if asPaths then importDirPaths else importDir)
          (nixDir + "/${name}");
        asList = attrValues asAttrs;
      in
      if type.check asAttrs then [ asAttrs ]
      else if type.check asList then [ asList ]
      else [ asAttrs ]
    else [ ];
in
{
  options = {
    nixDir = mkOption {
      type = nullable path;
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
    (name: mkMerge (if nixDir == null then [ ] else
    let
      opt = options.${name};
      internal = opt.internal or false;
      names =
        if internal then [ ] else
        if name == "nixDirAliases" then [ name ]
        else ([ name ] ++ config.nixDirAliases.${name} or [ ]);
      asPaths = !(elem name [ "nixDirPathAttrs" "nixDirAliases" ])
        && (elem name config.nixDirPathAttrs);
    in
    concatMap (importName asPaths opt.type) names));
}
