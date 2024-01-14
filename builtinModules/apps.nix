# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, genSystems, ... }:
let
  inherit (lib) isFunction mapAttrs mkIf mkMerge mkOption;
  inherit (lib.types) lazyAttrsOf nullOr raw;
  inherit (flakelight.types) optFunctionTo;

  isApp = x: (x ? type) && (x.type == "app") && (x ? program);

  mkApp = pkgs: app:
    let app' = if isFunction app then app pkgs else app; in
    if isApp app' then app' else { type = "app"; program = "${app'}"; };
in
{
  options = {
    app = mkOption {
      type = nullOr raw;
      default = null;
    };

    apps = mkOption {
      type = nullOr (optFunctionTo (lazyAttrsOf raw));
      default = null;
    };
  };

  config = mkMerge [
    (mkIf (config.app != null) {
      apps.default = config.app;
    })

    (mkIf (config.apps != null) {
      outputs.apps = genSystems (pkgs:
        mapAttrs (_: mkApp pkgs) (config.apps pkgs));
    })
  ];
}
