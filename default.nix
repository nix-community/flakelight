# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

nixpkgs:
let
  inherit (builtins) functionArgs isFunction isList isPath isString readDir;
  inherit (nixpkgs.lib) attrNames attrVals composeManyExtensions filter
    filterAttrs foldAttrs foldl genAttrs hasSuffix listToAttrs mapAttrs
    mapAttrsToList mapAttrs' mergeAttrs nameValuePair optional optionalAttrs
    optionalString parseDrvName pathExists pipe recursiveUpdate removePrefix
    removeSuffix zipAttrsWith;

  exports = {
    inherit mkFlake loadNixDir systems autoloadAttr ensureFn mergeListFns
      mergeAttrFns mergeModules callWith genPackages supportedSystem;
  };

  baseModule = src: inputs: root: {
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

  loadNixDir = path: genAttrs
    (pipe (readDir path) [
      attrNames
      (filter (s: s != "default.nix"))
      (filter (hasSuffix ".nix"))
      (map (removeSuffix ".nix"))
      (map (removePrefix "_"))
    ])
    (p: import (path + (if pathExists
      (path + "/_${p}.nix") then "/_${p}.nix" else "/${p}.nix")));

  autoloadAttr = nixDir: attr:
    if pathExists (nixDir + "/${attr}.nix")
    then import (nixDir + "/${attr}.nix")
    else if pathExists (nixDir + "/${attr}/default.nix")
    then import (nixDir + "/${attr}")
    else if pathExists (nixDir + "/${attr}")
    then loadNixDir (nixDir + "/${attr}")
    else null;

  autoAttrs = [
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
    "systems"
    "perSystem"
    "outputs"
  ];

  genAutoAttrs = nixDir:
    filterAttrs (_: v: v != null) (genAttrs autoAttrs (autoloadAttr nixDir));

  ensureFn = v: if isFunction v then v else _: v;

  mergeListFns = f1: f2: args: (f1 args) ++ (f2 args);
  mergeAttrFns = f1: f2: args: (f1 args) // (f2 args);

  mergeModules = m1: m2: {
    withOverlays = m1.withOverlays ++ m2.withOverlays;
    packages = m1.packages // m2.packages;
    devTools = mergeListFns m1.devTools m2.devTools;
    devShells = mergeAttrFns m1.devShells m2.devShells;
    env = mergeAttrFns m1.env m2.env;
    overlays = zipAttrsWith (_: composeManyExtensions)
      [ m1.overlays m2.overlays ];
    apps = mergeAttrFns m1.apps m2.apps;
    checks = mergeAttrFns m1.checks m2.checks;
    nixosModules = m1.nixosModules // m2.nixosModules;
    nixosConfigurations = m1.nixosConfigurations // m2.nixosConfigurations;
    templates = m1.templates // m2.templates;
    formatters = mergeAttrFns m1.formatters m2.formatters;
  };

  callWith = pkgs: x:
    let
      x' = ensureFn (if (isPath x) || (isString x) then import x else x);
    in
    callFn pkgs x';

  callFn = pkgs: f:
    if functionArgs f == { }
    then f pkgs
    else pkgs.callPackage f { };

  genPackages = pkgs: mapAttrs (_: callWith pkgs);

  getName = root: pkg: root.name or pkg.pname or (parseDrvName pkg).name;

  supportedSystem = { lib, stdenv, ... }: pkg:
    if pkg ? meta.platforms
    then lib.meta.availableOn stdenv.hostPlatform pkg
    else true;

  mkFlake = src: inputs: root:
    let
      modules = root.modules or pipe (inputs // { self = { }; }) [
        (filterAttrs (_: v: v ? flakeliteModule))
        (mapAttrsToList (_: v: v.flakeliteModule))
      ];

      params = exports // { inherit src inputs root'; };
      applyParams = v: ensureFn v params;

      moduleDefaults = {
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
          module' = moduleDefaults // module;
        in
        module' // {
          withOverlays = (applyParams module'.withOverlays)
          ++ optional (module' ? withOverlay) module'.withOverlay;
          packages = (applyParams module'.packages)
          // optionalAttrs (module' ? package) {
            default = module'.package;
          };
          devTools = ensureFn module'.devTools;
          devShells = mergeAttrFns (ensureFn module'.devShells)
            (_: optionalAttrs (module' ? devShell) {
              default = module'.devShell;
            });
          env = ensureFn module'.env;
          overlays = (applyParams module'.overlays)
          // optionalAttrs (module' ? overlay) {
            default = module'.overlay;
          };
          apps = mergeAttrFns (ensureFn module'.apps)
            (_: optionalAttrs (module' ? app) {
              default = module'.app;
            });
          checks = ensureFn module'.checks;
          nixosModules = (applyParams module'.nixosModules)
          // optionalAttrs (module' ? nixosModule) {
            default = module'.nixosModule;
          };
          nixosConfigurations = applyParams module'.nixosConfigurations;
          templates = (applyParams module'.templates)
          // optionalAttrs (module' ? template) {
            default = module'.template;
          };
          formatters = ensureFn module'.formatters;
        };

      root' =
        let
          nixDir = root.nixDir or (src + ./nix);
          rootWithAuto = (genAutoAttrs nixDir) // root;
        in
        normalizeModule rootWithAuto // {
          systems = applyParams rootWithAuto.systems or systems.linuxDefault;
          perSystem = ensureFn rootWithAuto.perSystem or (_: { });
          outputs = applyParams rootWithAuto.outputs or { };
          inherit nixDir;
        };

      merged = foldl mergeModules moduleDefaults
        ((map (m: normalizeModule (m src inputs root'))
          ([ baseModule ] ++ modules)) ++ [ root' ]);

      pkgsFor = system: import (inputs.nixpkgs or nixpkgs) {
        inherit system;
        overlays = merged.withOverlays ++ [
          (final: _: genPackages final merged.packages)
        ];
      };

      systemPkgs = listToAttrs (map
        (system: nameValuePair system (pkgsFor system))
        root'.systems);

      getPackagesFrom = pkgs: packageSet:
        genAttrs (attrNames packageSet) (p: pkgs.${p});

      mkCheck = pkgs: name: cmd: pkgs.runCommand "check-${name}" { } ''
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

      mergeOutputs = foldl
        (acc: new: recursiveUpdate acc ((ensureFn new) acc))
        { };

      replaceDefault = set:
        if set ? default
        then (removeAttrs set [ "default" ]) //
          { ${getName root' set.default} = set.default; }
        else set;
    in
    mergeOutputs [
      (optionalAttrs (merged.packages != { }) ({
        overlays.default = final: _: genPackages
          (final.appendOverlays merged.withOverlays)
          (replaceDefault merged.packages);
      } // eachSystem (pkgs: rec {
        packages = filterAttrs (_: supportedSystem pkgs)
          (getPackagesFrom pkgs merged.packages);
        checks = mapAttrs' (k: nameValuePair ("packages-" + k)) packages;
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
                  ${toString (mapAttrsToList (k: v: "${k}) ${v} \"$f\";;")
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
      (eachSystem ({ pkgs, lib, ... }:
        let
          checks = mapAttrs
            (k: v: if lib.isDerivation v then v else mkCheck pkgs k v)
            (merged.checks pkgs);
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
        checks = mergeOutputs (mapAttrsToList
          (k: v: {
            ${v.config.nixpkgs.system}."nixos-${k}" =
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
      } // (genPackages pkgs (merged.devShells pkgs))))
      (eachSystem root'.perSystem)
      root'.outputs
    ];

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
in
exports
