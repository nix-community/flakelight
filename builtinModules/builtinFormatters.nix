# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
in
{
  options.flakelight.builtinFormatters =
    mkEnableOption "default formatters" // { default = true; };

  config = mkIf config.flakelight.builtinFormatters {
    devShell.packages = pkgs: [
      pkgs.nixpkgs-fmt
      pkgs.nodePackages.prettier
    ];

    formatters = {
      "*.nix" = "nixpkgs-fmt";
      "*.md" = "prettier --write";
      "*.json" = "prettier --write";
      "*.yml" = "prettier --write";
    };
  };
}
