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
    formatters = pkgs:
      let
        nixfmt = "${pkgs.nixfmt}/bin/nixfmt";
        # prefer-file would be better but does not work with prose-wrap
        prettier = "${pkgs.prettier}/bin/prettier --write"
          + " --cache-location=.prettiercache"
          + " --config-precedence file-override --prose-wrap always";
      in
      {
        "*.nix" = mkDefault nixfmt;
        "*.md" = mkDefault prettier;
        "*.json" = mkDefault prettier;
        "*.yaml" = mkDefault prettier;
        "*.yml" = mkDefault prettier;
      };
  };
}
