# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

localInputs:
let
  inherit (builtins) intersectAttrs isPath readDir;
  inherit (localInputs.nixpkgs.lib) attrNames attrVals callPackageWith
    composeManyExtensions concat filter filterAttrs foldAttrs foldl functionArgs
    genAttrs hasSuffix isFunction isList isString listToAttrs mapAttrs
    mapAttrsToList mapAttrs' mergeAttrs nameValuePair optional optionalAttrs
    optionalString parseDrvName pathExists pipe recursiveUpdate removePrefix
    removeSuffix zipAttrsWith;

  exports = {
    inherit mkFlake systems importDir autoImport autoImportAttrs defaultPkgName
      supportedSystem mergeModules moduleAttrs rootAttrs ensureFn callFn
      filterArgs callPkg callPkgs tryImport mkApp mkCheck liftFn2 fnConcat
      fnMergeAttrs;
  };

  builtinModule = { src, inputs, root }: {
    inputs = {
      flakelite = localInputs.self;
      inherit (localInputs) nixpkgs;
    };
    withOverlays = params: [
      (final: prev: {
        flakelite = params // {
          inputs' = mapAttrs
            (_: mapAttrs
              (_: v: v.${prev.system} or { }))
            inputs;
          meta = {
            platforms = root.systems;
          } // optionalAttrs (root ? description) {
            inherit (root) description;
          } // optionalAttrs (root ? license) {
            license =
              if isList root.license
              then attrVals root.license final.lib.licenses
              else final.lib.licenses.${root.license};
          };
        };
      })
    ];
    checks = { pkgs, lib, ... }:
      (optionalAttrs (pathExists (src + /.editorconfig)) {
        editorconfig = "${lib.getExe pkgs.editorconfig-checker}"
          + optionalString (!pathExists (src + /.ecrc))
          " -disable-indent-size -disable-max-line-length";
      });
    devTools = pkgs: with pkgs; [ nixpkgs-fmt nodePackages.prettier ];
    formatters = {
      "*.nix" = "nixpkgs-fmt";
      "*.md | *.json | *.yml" = "prettier --write";
    };
  };

  importDir = path: genAttrs
    (pipe (readDir path) [
      attrNames
      (filter (s: s != "default.nix"))
      (filter (hasSuffix ".nix"))
      (map (removeSuffix ".nix"))
      (map (removePrefix "_"))
    ])
    (p: import (path + (if pathExists
      (path + "/_${p}.nix") then "/_${p}.nix" else "/${p}.nix")));

  autoImport = dir: attr:
    if pathExists (dir + "/${attr}.nix")
    then import (dir + "/${attr}.nix")
    else if pathExists (dir + "/${attr}/default.nix")
    then import (dir + "/${attr}")
    else if pathExists (dir + "/${attr}")
    then importDir (dir + "/${attr}")
    else null;

  moduleAttrs = [
    "inputs"
    "withOverlay"
    "withOverlays"
    "package"
    "packages"
    "devTools"
    "devShell"
    "devShells"
    "env"
    "overlay"
    "overlays"
    "app"
    "apps"
    "checks"
    "nixosModule"
    "nixosModules"
    "nixosConfigurations"
    "template"
    "templates"
    "formatters"
  ];

  rootAttrs = moduleAttrs ++ [
    "systems"
    "perSystem"
    "outputs"
    "nixDir"
  ];

  autoImportAttrs = dir: attrs:
    filterAttrs (_: v: v != null) (genAttrs attrs (autoImport dir));

  ensureFn = v: if isFunction v then v else _: v;

  liftFn2 = fn: a: b: args: fn (a args) (b args);

  fnConcat = liftFn2 concat;
  fnMergeAttrs = liftFn2 mergeAttrs;

  mergeOverlayAttrs = a: b: zipAttrsWith (_: composeManyExtensions) [ a b ];

  mergeModules = a: b: mapAttrs (n: v: v a.${n} b.${n}) {
    inputs = mergeAttrs;
    withOverlays = concat;
    packages = mergeAttrs;
    devTools = fnConcat;
    devShells = fnMergeAttrs;
    env = fnMergeAttrs;
    overlays = mergeOverlayAttrs;
    apps = fnMergeAttrs;
    checks = fnMergeAttrs;
    nixosModules = mergeAttrs;
    nixosConfigurations = mergeAttrs;
    templates = mergeAttrs;
    formatters = fnMergeAttrs;
  };

  callFn = args: f:
    let
      f' = ensureFn f;
    in
    if functionArgs f' == { } then f' args
    else f' (intersectAttrs (functionArgs f) args);

  filterArgs = x: args: callFn args x;

  tryImport = x: if (isPath x) || (isString x) then import x else x;

  callPkg = args: f:
    let
      f' = ensureFn (tryImport f);
    in
    if functionArgs f' == { } then f' args
    else (args.callPackage or (callPackageWith args)) f' { };

  callPkgs = pkgs: mapAttrs (_: callPkg pkgs);

  defaultPkgName = root: pkg: root.name or pkg.pname or (parseDrvName pkg).name;

  recUpdateSets = foldl (acc: x: recursiveUpdate acc ((ensureFn x) acc)) { };

  isApp = x: (x ? type) && (x.type == "app") && (x ? program);

  mkApp = pkgs: app:
    let
      app' = callFn pkgs app;
    in
    if isApp app' then app'
    else { type = "app"; program = "${app'}"; };

  mkCheck = pkgs: src: name: cmd:
    if pkgs.lib.isDerivation cmd then cmd else
    pkgs.runCommand "check-${name}" { } ''
      cp --no-preserve=mode -r ${src} src
      cd src
      ${cmd}
      touch $out
    '';

  supportedSystem = { lib, stdenv, ... }: pkg:
    if pkg ? meta.platforms
    then lib.meta.availableOn stdenv.hostPlatform pkg
    else true;

  systems = rec {
    linuxDefault = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    linuxAll = linuxDefault ++ [
      "armv6l-linux"
      "armv7l-linux"
      "i686-linux"
    ];
  };

  mkFlake = src: root:
    let
      nonSysArgs = exports // {
        args = nonSysArgs;
        flakelite = exports;
        root = root';
        inherit src;
        inherit (merged) inputs;
        inherit (merged.inputs.nixpkgs) lib;
      };

      applyNonSysArgs = callFn nonSysArgs;

      moduleAttrDefaults = {
        inputs = { };
        withOverlays = [ ];
        packages = { };
        devTools = _: [ ];
        devShells = _: { };
        env = _: { };
        overlays = { };
        apps = _: { };
        checks = _: { };
        nixosModules = { };
        nixosConfigurations = { };
        templates = { };
        formatters = _: { };
      };

      normalizeModule = module:
        let
          module' = moduleAttrDefaults // module;
        in
        module' // {
          withOverlays = (applyNonSysArgs module'.withOverlays)
          ++ optional (module' ? withOverlay) module'.withOverlay;
          packages = (applyNonSysArgs module'.packages)
          // optionalAttrs (module' ? package) {
            default = module'.package;
          };
          devTools = filterArgs module'.devTools;
          devShells = fnMergeAttrs (filterArgs module'.devShells)
            (_: optionalAttrs (module' ? devShell) {
              default = module'.devShell;
            });
          env = filterArgs module'.env;
          overlays = (applyNonSysArgs module'.overlays)
          // optionalAttrs (module' ? overlay) {
            default = module'.overlay;
          };
          apps = fnMergeAttrs (filterArgs module'.apps)
            (_: optionalAttrs (module' ? app) {
              default = module'.app;
            });
          checks = filterArgs module'.checks;
          nixosModules = (applyNonSysArgs module'.nixosModules)
          // optionalAttrs (module' ? nixosModule) {
            default = module'.nixosModule;
          };
          nixosConfigurations = applyNonSysArgs module'.nixosConfigurations;
          templates = (applyNonSysArgs module'.templates)
          // optionalAttrs (module' ? template) {
            default = module'.template;
          };
          formatters = filterArgs module'.formatters;
        };

      root' =
        let
          nixDir = root.nixDir or (src + ./nix);
          fullRoot = (autoImportAttrs nixDir rootAttrs) // root;
        in
        normalizeModule fullRoot // {
          modules = fullRoot.modules or
            (pipe (removeAttrs root'.inputs [ "self" ]) [
              (filterAttrs (_: v: v ? flakeliteModule))
              (mapAttrsToList (_: v: v.flakeliteModule))
            ]);
          systems = applyNonSysArgs (fullRoot.systems or systems.linuxDefault);
          perSystem = filterArgs (fullRoot.perSystem or { });
          outputs = applyNonSysArgs (fullRoot.outputs or { });
          inherit nixDir;
          raw = root;
        };

      merged = foldl mergeModules moduleAttrDefaults
        ((map (m: normalizeModule (applyNonSysArgs m))
          ([ builtinModule ] ++ root'.modules)) ++ [ root' ]);

      pkgsFor = system: import merged.inputs.nixpkgs {
        inherit system;
        overlays = merged.withOverlays ++ [
          (final: _: callPkgs final merged.packages)
        ];
      };

      systemPkgs = listToAttrs (map
        (system: nameValuePair system (pkgsFor system))
        root'.systems);

      eachSystem = fn: foldAttrs mergeAttrs { } (map
        (system: mapAttrs
          (_: v: { ${system} = v; })
          (fn systemPkgs.${system}))
        root'.systems);

      replaceDefault = set:
        if set ? default
        then (removeAttrs set [ "default" ]) //
          { ${defaultPkgName root' set.default} = set.default; }
        else set;
    in
    recUpdateSets [
      (optionalAttrs (merged.packages != { }) ({
        overlays.default = final: _: callPkgs
          (final.appendOverlays merged.withOverlays)
          (replaceDefault merged.packages);
      } // eachSystem (pkgs: rec {
        packages = filterAttrs (_: supportedSystem pkgs)
          (intersectAttrs merged.packages pkgs);
        checks = mapAttrs' (n: nameValuePair ("packages-" + n)) packages;
      })))
      (prev: optionalAttrs (merged.overlays != { }) ({
        overlays = mergeOverlayAttrs (prev.overlays or { }) merged.overlays;
      }))
      (eachSystem ({ pkgs, lib, ... }:
        optionalAttrs (merged.formatters pkgs != { }) rec {
          formatter = pkgs.writeShellScriptBin "formatter" ''
            PATH=${lib.makeBinPath (merged.devTools pkgs)}
            for f in "$@"; do
              if [ -d "$f" ]; then
                ${pkgs.fd}/bin/fd "$f" -Htf -x "$0"
              else
                case "$(${pkgs.coreutils}/bin/basename "$f")" in
                  ${toString (mapAttrsToList (n: v: "${n}) ${v} \"$f\";;")
                    (merged.formatters pkgs))}
                esac
              fi
            done &>/dev/null
          '';
          checks.formatting = mkCheck pkgs src "formatting" ''
            ${lib.getExe formatter} .
            ${pkgs.diffutils}/bin/diff -qr ${src} . |\
              sed 's/Files .* and \(.*\) differ/File \1 not formatted/g'
          '';
        }))
      (eachSystem (pkgs:
        let
          checks = mapAttrs (mkCheck pkgs src) (merged.checks pkgs);
        in
        optionalAttrs (checks != { }) { inherit checks; }))
      (eachSystem (pkgs:
        let
          apps = mapAttrs (_: mkApp pkgs) (merged.apps pkgs);
        in
        optionalAttrs (apps != { }) { inherit apps; }))
      (optionalAttrs (merged.nixosModules != { }) {
        inherit (merged) nixosModules;
      })
      (optionalAttrs (merged.nixosConfigurations != { }) {
        inherit (merged) nixosConfigurations;
        checks = recUpdateSets (mapAttrsToList
          (n: v: {
            ${v.config.nixpkgs.system}."nixos-${n}" =
              v.config.system.build.toplevel;
          })
          merged.nixosConfigurations);
      })
      (optionalAttrs (merged.templates != { }) {
        inherit (merged) templates;
      })
      (prev: eachSystem ({ pkgs, system, mkShell, ... }: {
        devShells.default = mkShell (merged.env pkgs // {
          inputsFrom = optional (prev ? packages.${system}.default)
            prev.packages.${system}.default;
          packages = merged.devTools pkgs;
        });
      } // (callPkgs pkgs (merged.devShells pkgs))))
      (eachSystem root'.perSystem)
      root'.outputs
    ];
in
exports
