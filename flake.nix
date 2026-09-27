# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{
  description = "A modular Nix flake framework for simplifying flake definitions";
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
  outputs =
    inputs:
    let
      lib = import ./. inputs;
    in
    lib.mkFlake ./. {
      inherit lib;
      functor = _: lib.mkFlake;
      templates = import ./templates;
      checks.statix = pkgs: "${pkgs.statix}/bin/statix check";
      outputs.tests = import ./tests inputs;
      formatters = { pkgs, lib, ... }: {
        "*.nix" = "${lib.getExe pkgs.nixfmt} -w78";
        "*.md" = "${lib.getExe pkgs.mdformat} --wrap 80";
      };
    };
}
