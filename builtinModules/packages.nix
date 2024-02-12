# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, genSystems, moduleArgs, ... }:
let
  inherit (builtins) hasAttr parseDrvName tryEval;
  inherit (lib) filterAttrs findFirst functionArgs mapAttrs' mapAttrs mkIf
    mkMerge mkOption nameValuePair optionalAttrs;
  inherit (lib.types) lazyAttrsOf str uniq;
  inherit (flakelight) supportedSystem;
  inherit (flakelight.types) nullable optCallWith overlay packageDef;

  genPkg = final: prev: name: pkg:
    let
      args = functionArgs pkg;
      noArgs = args == { };
      pkg' = if noArgs then { pkgs }: pkg pkgs else pkg;
      dependsOnSelf = hasAttr name (functionArgs pkg);
      dependsOnPkgs = noArgs || (args ? pkgs);
      selfOverride = {
        ${name} = prev.${name} or
          (throw "${name} depends on ${name}, but no existing ${name}.");
      };
      overrides = optionalAttrs dependsOnSelf selfOverride
        // optionalAttrs dependsOnPkgs { pkgs = final.pkgs // selfOverride; };
    in
    final.callPackage pkg' overrides;
  genPkgs = final: prev: pkgs:
    mapAttrs (name: genPkg final prev name) pkgs;
in
{
  options = {
    package = mkOption {
      type = nullable packageDef;
      default = null;
    };

    packages = mkOption {
      type = optCallWith moduleArgs (lazyAttrsOf packageDef);
      default = { };
    };

    pname = mkOption {
      type = nullable str;
      default = null;
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
          mockPkgs = import ../misc/nameMockedPkgs.nix prev;

          defaultPkgName = findFirst (x: (tryEval x).success)
            (throw ("Could not determine the name of the default package; " +
              "please set the `pname` flakelight option to the intended name."))
            [
              (assert config.pname != null; config.pname)
              (getName (mockPkgs.callPackage config.packages.default { }))
              (getName (import inputs.nixpkgs {
                inherit (prev.stdenv.hostPlatform) system;
                inherit (config.nixpkgs) config;
                overlays = config.withOverlays ++
                  [ (final: prev: genPkgs final prev config.packages) ];
              }).default)
            ];
        in
        (optionalAttrs (config.packages ? default) rec {
          default = genPkg final prev defaultPkgName
            config.packages.default;
          ${defaultPkgName} = default;
        }) // genPkgs final prev (removeAttrs config.packages [ "default" ]);

      overlay = final: prev: removeAttrs
        (config.packageOverlay (final.appendOverlays config.withOverlays) prev)
        [ "default" ];

      outputs = rec {
        packages = genSystems (pkgs:
          filterAttrs (_: supportedSystem pkgs)
            (mapAttrs (k: _: pkgs.${k}) config.packages));

        checks = mapAttrs
          (_: mapAttrs' (n: nameValuePair ("packages-" + n)))
          packages;
      };
    })

    (mkIf (config.packages ? default) {
      devShell.inputsFrom = pkgs: [ pkgs.default ];
    })
  ];
}
