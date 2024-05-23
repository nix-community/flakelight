# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

# Get a flakes inputs
{ lib, ... }:
src:
let
  inherit (builtins) fromJSON head isString mapAttrs readFile tail;
  inherit (lib) fix;

  json = fromJSON (readFile (src + "/flake.lock"));
  inherit (json) nodes;
  rootNode = nodes.${json.root};

  getInputName = base: ref:
    let next = getInputName json.root nodes.${base}.inputs.${head ref}; in
    if isString ref then ref
    else if ref == [ ] then base
    else getInputName next (tail ref);

  getInput = ref: resolved.${getInputName json.root ref};

  fetchNode = node: fetchTree (node.info or { } //
    removeAttrs node.locked [ "dir" ]);

  resolveFlakeNode = node: fix (self:
    let
      sourceInfo = fetchNode node;
      outPath = sourceInfo +
        (if node.locked ? dir then "/${node.locked.dir}" else "");
      inputs = (mapAttrs (_: getInput) (node.inputs or { })) //
        { inherit self; };
      outputs = (import (outPath + "/flake.nix")).outputs inputs;
    in
    outputs // sourceInfo // {
      _type = "flake";
      inherit outPath inputs outputs sourceInfo;
    });

  resolveNode = node:
    if node.flake or true then resolveFlakeNode node else fetchNode node;

  resolved = mapAttrs (_: resolveNode) nodes;
in
mapAttrs (_: getInput) rootNode.inputs
