# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (builtins) isPath isString;
  inherit (lib) mkOption mkOptionType mkIf mkMerge;
  inherit (lib.types) lazyAttrsOf nullOr;
  inherit (lib.options) mergeEqualOption;

  template = mkOptionType {
    name = "template";
    description = "template definition";
    descriptionClass = "noun";
    check = x: (x ? path) && (isPath x.path) &&
      (x ? description) && (isString x.description) &&
      ((! x ? welcomeText) || (isString x.welcomeText));
    merge = mergeEqualOption;
  };
in
{
  options = {
    template = mkOption {
      type = nullOr template;
      default = null;
    };

    templates = mkOption {
      type = lazyAttrsOf template;
      default = { };
    };
  };

  config = mkMerge [
    (mkIf (config.template != null) {
      templates.default = config.template;
    })

    (mkIf (config.templates != { }) {
      outputs = { inherit (config) templates; };
    })
  ];
}
