# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
in
{
  options.flakelight.builtinFormatters =
    mkEnableOption "default formatters" //
    { default = config.formatter == null; };

  config = mkIf config.flakelight.builtinFormatters {
    devShell.packages = pkgs: [
      pkgs.nixpkgs-fmt
      pkgs.nodePackages.prettier
    ];

    formatters = pkgs:
      let
        nixpkgs-fmt = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
        prettier = "${pkgs.nodePackages.prettier}/bin/prettier --write";
      in
      {
        "*.nix" = nixpkgs-fmt;
        "*.md" = prettier;
        "*.json" = prettier;
        "*.yaml" = prettier;
        "*.yml" = prettier;
      };
  };
}
