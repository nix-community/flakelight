# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, genSystems, ... }:
let
  inherit (lib) isFunction mapAttrs mkIf mkMerge mkOption;
  inherit (lib.types) lazyAttrsOf raw;
  inherit (flakelight.types) nullable optFunctionTo;

  isApp = x: (x ? type) && (x.type == "app") && (x ? program);

  mkApp = pkgs: app:
    let app' = if isFunction app then app pkgs else app; in
    if isApp app' then app' else { type = "app"; program = "${app'}"; };
in
{
  options = {
    app = mkOption {
      type = nullable raw;
      default = null;
    };

    apps = mkOption {
      type = nullable (optFunctionTo (lazyAttrsOf raw));
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
