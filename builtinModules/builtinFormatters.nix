# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (lib) mkDefault mkEnableOption mkIf;
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
        # prefer-file would be better but does not work with prose-wrap
        prettier = "${pkgs.nodePackages.prettier}/bin/prettier --write"
          + " --cache-location=.prettiercache"
          + " --config-precedence file-override --prose-wrap always";
      in
      {
        "*.nix" = mkDefault nixpkgs-fmt;
        "*.md" = mkDefault prettier;
        "*.json" = mkDefault prettier;
        "*.yaml" = mkDefault prettier;
        "*.yml" = mkDefault prettier;
      };
  };
}
