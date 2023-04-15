# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

nixpkgs:
let
  inherit (builtins) functionArgs isFunction isList isPath isString readDir;
  inherit (nixpkgs.lib) attrNames attrVals callPackageWith composeManyExtensions
    filter filterAttrs foldAttrs foldl genAttrs hasSuffix listToAttrs mapAttrs
    mapAttrsToList mapAttrs' mergeAttrs nameValuePair optional optionalAttrs
    optionalString parseDrvName pathExists pipe recursiveUpdate removePrefix
    removeSuffix zipAttrsWith;

  exports = {
    inherit mkFlake systems importDir autoImport autoImportAttrs defaultPkgName
      supportedSystem mergeModules moduleAttrs rootAttrs ensureFn fnConcat
      fnUpdate callFn callAuto callAttrsAuto;
  };

  builtinModule = src: inputs: root: {
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

  fnConcat = f1: f2: args: (f1 args) ++ (f2 args);
  fnUpdate = f1: f2: args: (f1 args) // (f2 args);

  mergeModules = m1: m2: {
    withOverlays = m1.withOverlays ++ m2.withOverlays;
    packages = m1.packages // m2.packages;
    devTools = fnConcat m1.devTools m2.devTools;
    devShells = fnUpdate m1.devShells m2.devShells;
    env = fnUpdate m1.env m2.env;
    overlays = zipAttrsWith (_: composeManyExtensions)
      [ m1.overlays m2.overlays ];
    apps = fnUpdate m1.apps m2.apps;
    checks = fnUpdate m1.checks m2.checks;
    nixosModules = m1.nixosModules // m2.nixosModules;
    nixosConfigurations = m1.nixosConfigurations // m2.nixosConfigurations;
    templates = m1.templates // m2.templates;
    formatters = fnUpdate m1.formatters m2.formatters;
  };

  callFn = args: f:
    if functionArgs f == { }
    then f args
    else
      if args ? callPackage
      then args.callPackage f { }
      else callPackageWith args f { };

  callAuto = args: x:
    let
      x' = ensureFn (if (isPath x) || (isString x) then import x else x);
    in
    callFn args x';

  callAttrsAuto = args: mapAttrs (_: callAuto args);

  defaultPkgName = root: pkg: root.name or pkg.pname or (parseDrvName pkg).name;

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

  mkFlake = src: inputs: root:
    let
      modules = root.modules or pipe (inputs // { self = { }; }) [
        (filterAttrs (_: v: v ? flakeliteModule))
        (mapAttrsToList (_: v: v.flakeliteModule))
      ];

      inputs' = { inherit nixpkgs; } // inputs;

      nonSysArgs = exports // {
        args = nonSysArgs;
        flakelite = exports;
        inherit src;
        inputs = inputs';
        root = root';
        inherit (inputs.nixpkgs) lib;
      };

      applyNonSysArgs = x: ensureFn x nonSysArgs;

      moduleAttrDefaults = {
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
          devTools = ensureFn module'.devTools;
          devShells = fnUpdate (ensureFn module'.devShells)
            (_: optionalAttrs (module' ? devShell) {
              default = module'.devShell;
            });
          env = ensureFn module'.env;
          overlays = (applyNonSysArgs module'.overlays)
          // optionalAttrs (module' ? overlay) {
            default = module'.overlay;
          };
          apps = fnUpdate (ensureFn module'.apps)
            (_: optionalAttrs (module' ? app) {
              default = module'.app;
            });
          checks = ensureFn module'.checks;
          nixosModules = (applyNonSysArgs module'.nixosModules)
          // optionalAttrs (module' ? nixosModule) {
            default = module'.nixosModule;
          };
          nixosConfigurations = applyNonSysArgs module'.nixosConfigurations;
          templates = (applyNonSysArgs module'.templates)
          // optionalAttrs (module' ? template) {
            default = module'.template;
          };
          formatters = ensureFn module'.formatters;
        };

      root' =
        let
          nixDir = root.nixDir or (src + ./nix);
          fullRoot = (autoImportAttrs nixDir rootAttrs) // root;
        in
        normalizeModule fullRoot // {
          systems = applyNonSysArgs fullRoot.systems or systems.linuxDefault;
          perSystem = ensureFn fullRoot.perSystem or (_: { });
          outputs = applyNonSysArgs fullRoot.outputs or { };
          inherit nixDir;
          raw = root;
        };

      merged = foldl mergeModules moduleAttrDefaults
        ((map (m: normalizeModule (m src inputs' root'))
          ([ builtinModule ] ++ modules)) ++ [ root' ]);

      pkgsFor = system: import inputs'.nixpkgs {
        inherit system;
        overlays = merged.withOverlays ++ [
          (final: _: callAttrsAuto final merged.packages)
        ];
      };

      systemPkgs = listToAttrs (map
        (system: nameValuePair system (pkgsFor system))
        root'.systems);

      replaceAttrsFrom = source: attrset:
        genAttrs (attrNames attrset) (n: source.${n});

      mkCheck = pkgs: name: cmd:
        if pkgs.lib.isDerivation cmd then cmd else
        pkgs.runCommand "check-${name}" { } ''
          cp --no-preserve=mode -r ${src} src
          cd src
          ${cmd}
          touch $out
        '';

      isApp = x: (x ? type) && (x.type == "app") && (x ? program);

      mkApp = pkgs: app:
        let
          app' = callFn pkgs (ensureFn app);
        in
        if isApp app' then app'
        else { type = "app"; program = "${app'}"; };

      eachSystem = fn: foldAttrs mergeAttrs { } (map
        (system: mapAttrs
          (_: v: { ${system} = v; })
          (fn systemPkgs.${system}))
        root'.systems);

      recUpdateSets = foldl
        (acc: new: recursiveUpdate acc ((ensureFn new) acc))
        { };

      replaceDefault = set:
        if set ? default
        then (removeAttrs set [ "default" ]) //
          { ${defaultPkgName root' set.default} = set.default; }
        else set;
    in
    recUpdateSets [
      (optionalAttrs (merged.packages != { }) ({
        overlays.default = final: _: callAttrsAuto
          (final.appendOverlays merged.withOverlays)
          (replaceDefault merged.packages);
      } // eachSystem (pkgs: rec {
        packages = filterAttrs (_: supportedSystem pkgs)
          (replaceAttrsFrom pkgs merged.packages);
        checks = mapAttrs' (n: nameValuePair ("packages-" + n)) packages;
      })))
      (prev: optionalAttrs (merged.overlays != { }) ({
        overlays = zipAttrsWith (_: composeManyExtensions)
          [ (prev.overlays or { }) merged.overlays ];
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
          checks.formatting = mkCheck pkgs "formatting" ''
            ${lib.getExe formatter} .
            ${pkgs.diffutils}/bin/diff -qr ${src} . |\
              sed 's/Files .* and \(.*\) differ/File \1 not formatted/g'
          '';
        }))
      (eachSystem (pkgs:
        let
          checks = mapAttrs (mkCheck pkgs) (merged.checks pkgs);
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
      } // (callAttrsAuto pkgs (merged.devShells pkgs))))
      (eachSystem root'.perSystem)
      root'.outputs
    ];
in
exports
