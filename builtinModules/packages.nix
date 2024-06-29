# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, inputs, flakelight, genSystems, moduleArgs, ... }:
let
  inherit (builtins) hasAttr parseDrvName tryEval;
  inherit (lib) findFirst functionArgs mapAttrs' mapAttrs mkIf mkMerge mkOption
    nameValuePair optionalAttrs optionals;
  inherit (lib.types) lazyAttrsOf str uniq;
  inherit (flakelight.types) nullable optFunctionTo overlay packageDef;

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

  getPkgDefs = pkgs: config.packages (moduleArgs // { inherit (pkgs) system; });
in
{
  options = {
    package = mkOption {
      type = nullable packageDef;
      default = null;
    };

    packages = mkOption {
      type = nullable (optFunctionTo (lazyAttrsOf packageDef));
      default = null;
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

    (mkIf (config.packages != null) {
      packageOverlay = final: prev:
        let
          pkgDefs = getPkgDefs prev;
          getName = pkg: pkg.pname or (parseDrvName pkg.name).name;
          mockPkgs = import ../misc/nameMockedPkgs.nix prev;

          defaultPkgName = findFirst (x: (tryEval x).success)
            (throw ("Could not determine the name of the default package; " +
              "please set the `pname` flakelight option to the intended name."))
            [
              (assert config.pname != null; config.pname)
              (getName (mockPkgs.callPackage pkgDefs.default { }))
              (getName (import inputs.nixpkgs {
                inherit (prev.stdenv.hostPlatform) system;
                inherit (config.nixpkgs) config;
                overlays = config.withOverlays ++
                  [ (final: prev: genPkgs final prev pkgDefs) ];
              }).default)
            ];
        in
        (optionalAttrs (pkgDefs ? default) rec {
          default = genPkg final prev defaultPkgName pkgDefs.default;
          ${defaultPkgName} = default;
        }) // genPkgs final prev (removeAttrs pkgDefs [ "default" ]);

      overlay = final: prev: removeAttrs
        (config.packageOverlay (final.appendOverlays config.withOverlays) prev)
        [ "default" ];

      outputs = rec {
        packages = genSystems (pkgs:
          mapAttrs (k: _: pkgs.${k}) (getPkgDefs pkgs));

        checks = mapAttrs
          (_: mapAttrs' (n: nameValuePair ("packages-" + n)))
          packages;
      };

      devShell.inputsFrom = pkgs:
        optionals ((getPkgDefs pkgs) ? default) [ pkgs.default ];
    })
  ];
}
