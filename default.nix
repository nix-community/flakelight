# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

localInputs:
let
  inherit (builtins) intersectAttrs isPath readDir;
  inherit (localInputs.nixpkgs.lib) attrNames attrVals callPackageWith
    composeManyExtensions concat concatStringsSep filter filterAttrs foldAttrs
    foldl functionArgs genAttrs hasSuffix isFunction isList isString listToAttrs
    mapAttrs mapAttrsToList mapAttrs' mergeAttrs nameValuePair optional
    optionalAttrs optionalString parseDrvName pathExists pipe recursiveUpdate
    removePrefix removeSuffix zipAttrsWith;

  /* Attributes in flakelite's lib output.
  */
  exports = {
    inherit mkFlake systems importDir autoImport autoImportAttrs defaultPkgName
      supportedSystem mergeModules moduleAttrs rootAttrs ensureFn callFn
      filterArgs callPkg callPkgs tryImport mkApp mkCheck liftFn2 fnConcat
      fnMergeAttrs;
  };

  /* Module which is always included as first module.
  */
  builtinModule = { src, inputs, root }: {
    # Ensures nixpkgs and flakelite are available for modules.
    inputs = {
      flakelite = localInputs.self;
      inherit (localInputs) nixpkgs;
    };
    withOverlays = params: [
      (final: prev: {
        # Allows access to flakelite lib functions from package sets.
        # Also adds pkgs-specific additional args.
        flakelite = params // {
          # Inputs with system auto-selected.
          # i.e. inputs.self.packages.${system} -> inputs'.self.packages
          inputs' = mapAttrs
            (_: mapAttrs
              (_: v: v.${prev.system} or { }))
            inputs;
          # Default package meta attribute generated from root module attrs.
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
      # Enable editorconfig support if detected.
      # By default, high false-positive flags are disabled.
      (optionalAttrs (pathExists (src + /.editorconfig)) {
        editorconfig = "${lib.getExe pkgs.editorconfig-checker}"
          + optionalString (!pathExists (src + /.ecrc))
          " -disable-indent-size -disable-max-line-length";
      });
    shellHook = { lib, flakelite }: ''
      if [ -f flake.nix ] && [ -d .git/hooks ] &&
         [ ! -f .git/hooks/pre-commit ]; then
        echo Installing git pre-commit hook...
        cp ${lib.getExe flakelite.inputs'.flakelite.packages.pre-commit
            } .git/hooks
      fi
    '';
    devTools = pkgs: with pkgs; [ nixpkgs-fmt nodePackages.prettier ];
    formatters = {
      "*.nix" = "nixpkgs-fmt";
      "*.md | *.json | *.yml" = "prettier --write";
    };
  };

  /* Import each nix file in a directory as attrs. Attr name is file name with
     extension stripped. To allow use in an importable directory, default.nix is
     skipped. To provide a file that will result in a "default" attr, name the
     file "_default.nix".
  */
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

  /* Try to load an attr from a directory. If a nix file by that name exits,
     import it. If an importable directory with that name exists, import it.
     Else, if a non-importable directory with that name exists, load the nix
     files in that dir as an attrset. Returns null if the attr could not be
     loaded.
  */
  autoImport = dir: attr:
    if pathExists (dir + "/${attr}.nix")
    then import (dir + "/${attr}.nix")
    else if pathExists (dir + "/${attr}/default.nix")
    then import (dir + "/${attr}")
    else if pathExists (dir + "/${attr}")
    then importDir (dir + "/${attr}")
    else null;

  /* List of attrs that can be provided by a module.
  */
  moduleAttrs = [
    "inputs"
    "withOverlay"
    "withOverlays"
    "package"
    "packages"
    "devTools"
    "shellHook"
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

  /* List of handled attrs in root module. Does not have optionally checked
     attrs like name, description, or license, or attrs used by modules.
  */
  rootAttrs = moduleAttrs ++ [
    "systems"
    "perSystem"
    "outputs"
    "nixDir"
  ];

  /* Generate an attrset by importing attrs from dir. Filters null values.
  */
  autoImportAttrs = dir: attrs:
    filterAttrs (_: v: v != null) (genAttrs attrs (autoImport dir));

  /* Makes the parameter callable, if it isn't. This allows values that are not
     always functions to be applied to parameters.
  */
  ensureFn = v: if isFunction v then v else _: v;

  /* Takes a binary function and returns a binary function that operates on
     functions that return the original parameter types.

     Type: liftFn2 :: (a -> b -> c) -> (d -> a) -> (d -> b) -> d -> c
  */
  liftFn2 = fn: a: b: args: fn (a args) (b args);

  fnConcat = liftFn2 concat;
  fnMergeAttrs = liftFn2 mergeAttrs;

  /* Takes a function which takes a list, and returns a binary function.

     Type: mkBinary :: ([a] -> b) -> a -> a -> b
  */
  mkBinary = fn: a: b: fn [ a b ];

  /* Merges attrsets of overlays, combining overlays with same name.
  */
  mergeOverlayAttrs = mkBinary (zipAttrsWith (_: composeManyExtensions));

  fnConcatScripts = liftFn2 (mkBinary (concatStringsSep "\n"));

  mergeModules = a: b: mapAttrs (n: v: v a.${n} b.${n}) {
    inputs = mergeAttrs;
    withOverlays = concat;
    packages = mergeAttrs;
    devTools = fnConcat;
    shellHook = fnConcatScripts;
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

  /* Calls f with required arguments from args. If the function does not have
     named arguments, just passes it args instead of nothing like callPackage
     does. If f is not a function, returns f.
  */
  callFn = args: f:
    let
      f' = ensureFn f;
    in
    if functionArgs f' == { } then f' args
    else f' (intersectAttrs (functionArgs f) args);

  /* Ensures x is called with only it's required parameters.
  */
  filterArgs = x: args: callFn args x;

  /* If arg is importable, imports it, else returns arg as is.
  */
  tryImport = x: if (isPath x) || (isString x) then import x else x;

  /* Like callFn, but intended for functions that return derivations. Uses
     callPackage so will make result overridable. Trys importing the value if a
     path.
  */
  callPkg = args: f:
    let
      f' = ensureFn (tryImport f);
    in
    if functionArgs f' == { } then f' args
    else (args.callPackage or (callPackageWith args)) f' { };

  callPkgs = pkgs: mapAttrs (_: callPkg pkgs);

  /* Gets the name for the default package using value set in root module or
     derivation attrs.
  */
  defaultPkgName = root: pkg: root.name or pkg.pname or (parseDrvName pkg).name;

  /* Merges elements of a list of sets recursively. Each element can optionally
     be a function that takes the merged previous elements.
  */
  recUpdateSets = foldl (acc: x: recursiveUpdate acc ((ensureFn x) acc)) { };

  isApp = x: (x ? type) && (x.type == "app") && (x ? program);

  /* Turns app into an app attribute, if it is not already. Passes it pkgs if it
     is a function.
  */
  mkApp = pkgs: app:
    let
      app' = callFn pkgs app;
    in
    if isApp app' then app'
    else { type = "app"; program = "${app'}"; };

  /* Makes cmd into a derivation for a flake's checks output. If it is not
     already a derivation, makes one that runs cmd on the flake source and
     depends on its success. Passes cmd pkgs if it is its a function.
  */
  mkCheck = pkgs: src: name: cmd:
    let
      cmd' = callFn pkgs cmd;
    in
    if pkgs.lib.isDerivation cmd' then cmd' else
    pkgs.runCommand "check-${name}" { } ''
      cp --no-preserve=mode -r ${src} src
      cd src
      ${cmd'}
      touch $out
    '';

  /* Takes a packages set and a package and returns true if the package is
     supported on the system for that packages set. If unknown, returns true.
  */
  supportedSystem = { lib, stdenv, ... }: pkg:
    if pkg ? meta.platforms
    then lib.meta.availableOn stdenv.hostPlatform pkg
    else true;

  systems = rec {
    # Linux systems with binary caches.
    linuxDefault = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    # Linux systems supported as a host platform.
    linuxAll = linuxDefault ++ [
      "armv6l-linux"
      "armv7l-linux"
      "i686-linux"
    ];
  };

  /* Creates flake outputs; takes the path of the flake and the root module.
  */
  mkFlake = src: root:
    let
      # These are passed to modules and non-system-dependent module attrs.
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
        shellHook = _: "";
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
          shellHook = filterArgs module'.shellHook;
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

      # Root module with autoloads, normalization, and additional attrs.
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

      # Merge result of all the modules.
      merged = foldl mergeModules moduleAttrDefaults
        ((map (m: normalizeModule (applyNonSysArgs m))
          ([ builtinModule ] ++ root'.modules)) ++ [ root' ]);

      # Returns package set for a system.
      pkgsFor = system: import merged.inputs.nixpkgs {
        inherit system;
        overlays = merged.withOverlays ++ [
          (final: _: callPkgs final merged.packages)
        ];
      };

      # Attrset mapping systems to corresponding package sets.
      systemPkgs = listToAttrs (map
        (system: nameValuePair system (pkgsFor system))
        root'.systems);

      # Calls fn for each supported system. Fn should return an attrset whose
      # attrs normally would have values in system attrs. Merges results into
      # attrset with system attrs.
      eachSystem = fn: foldAttrs mergeAttrs { } (map
        (system: mapAttrs
          (_: v: { ${system} = v; })
          (fn systemPkgs.${system}))
        root'.systems);

      # Replaces the "default" attr in set with the default package name.
      replaceDefault = set:
        if set ? default
        then (removeAttrs set [ "default" ]) //
          { ${defaultPkgName root' set.default} = set.default; }
        else set;
    in
    recUpdateSets [
      (optionalAttrs (merged.packages != { }) ({
        # Packages in overlay depend on withOverlays which are not in pkg set.
        overlays.default = final: _: callPkgs
          (final.appendOverlays merged.withOverlays)
          (replaceDefault merged.packages);
      } // eachSystem (pkgs: rec {
        # Packages are generated in overlay on system pkgs; grab from there.
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
          shellHook = merged.shellHook pkgs;
        });
      } // (callPkgs pkgs (merged.devShells pkgs))))
      (eachSystem root'.perSystem)
      root'.outputs
    ];
in
exports
