# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, ... }:
let
  inherit (builtins) parseDrvName;
  inherit (lib) filterAttrs mapAttrs mapAttrs' mkIf mkMerge mkOption
    nameValuePair optionalAttrs;
  inherit (lib.types) lazyAttrsOf nullOr uniq;
  inherit (flakelight) supportedSystem;
  inherit (flakelight.types) overlay packageDef;

  genPkg = pkgs: pkg: pkgs.callPackage pkg { };
  genPkgs = pkgs: mapAttrs (_: genPkg pkgs) config.packages;
in
{
  options = {
    package = mkOption {
      type = nullOr packageDef;
      default = null;
    };

    packages = mkOption {
      type = lazyAttrsOf packageDef;
      default = { };
    };

    packageOverlay = mkOption {
      internal = true;
      type = uniq overlay;
      default = _: _: { };
    };
  };

  config = mkMerge [
    (mkIf (config.package != null) {
      packages.default = config.package;
    })

    (mkIf (config.packages != { }) {
      packageOverlay = final: prev:
        let
          getName = pkg: pkg.pname or (parseDrvName pkg.name).name;
          defaultPkgName = getName (import inputs.nixpkgs {
            inherit (prev.stdenv.hostPlatform) system;
            inherit (config.nixpkgs) config;
            overlays = config.withOverlays ++ [ (final: _: genPkgs final) ];
          }).default;
        in
        (optionalAttrs (config.packages ? default) {
          ${defaultPkgName} = genPkg final config.packages.default;
        }) // genPkgs final;

      overlay = final: prev: removeAttrs
        (config.packageOverlay (final.appendOverlays config.withOverlays) prev)
        [ "default" ];

      perSystem = pkgs: rec {
        packages = filterAttrs (_: supportedSystem pkgs) (genPkgs pkgs);

        checks = mapAttrs' (n: nameValuePair ("packages-" + n)) packages;
      };
    })
  ];
}
