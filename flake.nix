# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{
  description =
    "A modular Nix flake framework for simplifying flake definitions";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  outputs = inputs:
    let flakelight = import ./. inputs; in
    flakelight ./. {
      outputs = flakelight;
      templates = import ./templates;
      checks.statix = pkgs: "${pkgs.statix}/bin/statix check";
    };
}
