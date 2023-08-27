# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.flakelight.builtinFormatters =
    mkEnableOption "default formatters" // { default = true; };

  config = {
    devShell.packages = pkgs: [
      pkgs.nixpkgs-fmt
      pkgs.nodePackages.prettier
    ];

    formatters = {
      "*.nix" = "nixpkgs-fmt";
      "*.md | *.json | *.yml" = "prettier --write";
    };
  };
}
