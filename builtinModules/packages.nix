# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelite, ... }:
let
  inherit (builtins) attrNames functionArgs intersectAttrs parseDrvName;
  inherit (lib) composeManyExtensions filterAttrs fix genAttrs mapAttrs mapAttrs'
    mkIf mkMerge mkOption mkOrder nameValuePair optional optionalAttrs remove;
  inherit (lib.types) lazyAttrsOf nullOr;
  inherit (flakelite) supportedSystem;
  inherit (flakelite.types) packageDef;

  getName = pkg: pkg.pname or (parseDrvName pkg.name).name;

  callPkg = pkgs: def: def (intersectAttrs (functionArgs def) pkgs);
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
  };

  config = mkMerge [
    (mkIf (config.package != null) {
      packages.default = config.package;
    })

    (mkIf (config.packages != { }) {
      withOverlays = mkOrder 2000 (final: prev:
        let
          pkgNames = attrNames config.packages;
          pkgNames' = remove "default" pkgNames;
          defaultName = getName (fix (self:
            prev // (genAttrs pkgNames
              (n: callPkg self config.packages.${n})))).default;
        in
        (optionalAttrs (config.packages ? default) {
          ${defaultName} = final.callPackage config.packages.default { };
        }) //
        (genAttrs pkgNames' (n: final.callPackage config.packages.${n} { })));

      overlays.default = final: prev:
        let
          pkgs' = fix (composeManyExtensions config.withOverlays) prev;
          defaultName = getName (callPkg pkgs' config.packages.default);
          pkgNames = (remove "default" (attrNames config.packages))
            ++ (optional (config.packages ? default) defaultName);
          pkgs = final.appendOverlays config.withOverlays;
        in
        genAttrs pkgNames (n: pkgs.${n});

      perSystem = pkgs: rec {
        packages = filterAttrs (_: supportedSystem pkgs)
          (mapAttrs (_: v: pkgs.callPackage v { }) config.packages);

        checks = mapAttrs' (n: nameValuePair ("packages-" + n)) packages;
      };
    })
  ];
}
