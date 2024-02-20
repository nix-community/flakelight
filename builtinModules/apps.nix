# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, genSystems, ... }:
let
  inherit (lib) isStringLike mapAttrs mkIf mkMerge mkOption mkOptionType;
  inherit (lib.types) coercedTo lazyAttrsOf pathInStore;
  inherit (lib.options) mergeEqualOption;
  inherit (flakelight.types) nullable optFunctionTo;

  app = mkOptionType {
    name = "app";
    description = "flake app";
    descriptionClass = "noun";
    check = x: (x ? type) && (x.type == "app") &&
      (x ? program) && (pathInStore.check x.program);
    merge = mergeEqualOption;
  };

  stringLike = mkOptionType {
    name = "stringLike";
    description = "string-convertible value";
    descriptionClass = "noun";
    check = isStringLike;
    merge = mergeEqualOption;
  };

  mkApp = app: { type = "app"; program = "${app}"; };

  appType = optFunctionTo (coercedTo stringLike mkApp app);
in
{
  options = {
    app = mkOption {
      type = nullable appType;
      default = null;
    };

    apps = mkOption {
      type = nullable (optFunctionTo (lazyAttrsOf appType));
      default = null;
    };
  };

  config = mkMerge [
    (mkIf (config.app != null) {
      apps.default = config.app;
    })

    (mkIf (config.apps != null) {
      outputs.apps = genSystems (pkgs:
        mapAttrs (_: v: v pkgs) (config.apps pkgs));
    })
  ];
}
