# API Guide

## lib

This section covers important functions available in Flakelight's lib attribute.

### mkFlake

The outputs of a flake using Flakelight are created using the `mkFlake`
function. When called directly, Flakelight invokes `mkFlake`, as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      # Your flake configuration here
    };
}
```

To call `mkFlake` explicitly, you can do:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight.lib.mkFlake ./. {
      # Your flake configuration here
    };
}
```

`mkFlake` takes two parameters: the path to the flake's source and a Flakelight
module.

If you need access to module args, you can write it as bellow:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, config, ... }: {
      # Your flake configuration here
    });
}
```

## Module arguments

The following module arguments are available:

- `src`: The flake's source directory
- `lib`: nixpkgs lib attribute
- `config`: configured option values
- `options`: available options
- `flakelight`: flakelight lib attribute
- `inputs`: value of inputs option
- `outputs`: resulting output (i.e. final flake attributes)
- `pkgsFor`: attrset mapping systems to the pkgs set for that system
- `moduleArgs`: All of the available arguments (passed to auto-loaded files)

## Additional pkgs values

Functions that take the package set as an argument, such as package definitions
or `perSystem` values, have several additional values available in the package
set.

The `src`, `flakelight`, `inputs`, `outputs`, and `moduleArgs` attributes are
the same as the above module arguments.

`inputs'` and `outputs'` are transformed versions of `inputs` and `outputs` with
system preselected. I.e., `inputs.emacs-overlay.packages.x86_64-linux.default`
can be accessed as `inputs'.emacs-overlay.packages.default`.

`defaultMeta` is a derivation meta attribute set generated from options. Modules
setting `packages.default` should use this to allow meta attributes to be
configured.

## Module options

This section covers the options available to modules.

### inputs

```
Type: AttrsOf FlakeInput
```

The `inputs` option is an attrset of the flake inputs used by flakelight
modules. These inputs get passed as the `inputs` module argument, and are used
for `inputs` and `inputs'` in the package set.

Default values are automatically initialized from your flake inputs by reading
your `flake.lock`. Note that this does not include the `self` argument; for
using `self`, use `inherit inputs` or otherwise define inputs. The default
values also are not affected by nix command flags like `--override-input`, so
inputs should be passed to enable full CLI functionality.

Flakelight will add a recent `nixpkgs` input if your flake does not have one.
Other flakelight modules may provide default inputs for their dependencies.

To use a different nixpkgs from the built-in default (passing all inputs):

```nix
{
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = { flakelight, ... }@inputs:
    flakelight ./. {
      inherit inputs;
    };
}
```

Or to just pass just the nixpkgs input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flakelight.url = "github:nix-community/flakelight";
  };
  outputs = { flakelight, nixpkgs, ... }:
    flakelight ./. {
      inputs.nixpkgs = nixpkgs;
    };
}
```

### systems

```
Type: [SystemStr]
```

The `systems` option sets which systems per-system outputs should be created
for.

If not set, the default is `x86_64-linux` and `aarch64-linux`.

To also support `i686-linux` and `armv7l-linux`, you would configure `systems`
as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" "armv7l-linux" ];
    };
}
```

To support all systems supported by flakes, set `systems` as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, ... }: {
      systems = lib.systems.flakeExposed;
    });
}
```

To support all Linux systems supported by flakes, set `systems` as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, ... }: {
      systems = lib.intersectLists
        lib.systems.doubles.linux
        lib.systems.flakeExposed;
    });
}
```

### nixDir

```
Type: Path | null
```

The `nixDir` option is `./nix` by default and sets which directory to use to
automatically load nix files to configure flake options from.

For a given option, the following is checked in order:

- If `${nixDir}/option.nix` exists, the value is the file imported.
- Else if `${nixDir}/option` is a directory with a `default.nix`, the value is
  the directory imported.
- Else if `${nixDir}/option` is a directory, and option accepts an attrset, the
  value in an attrset with an attr for each importable item in the directory,
  for which the values are the corresponding items imported. An importable item
  is a file ending with `.nix` or a directory containing a `default.nix`. This
  is the same as the flakelight `importDir` function.
- Else if `${nixDir}/option` is a directory, and option accepts an list, it
  results in a list, the elements of which are the values of the attrset from
  the prior branch.

To enable using a directory for an attrset that includes a `default` attribute,
attr names can be escaped with an underscore. For example,
`${nixDir}/nix/packages/_default.nix` will be loaded as `packages.default`.

Aliases for options can be set with the `nixDirAliases` option. For example, by
default `nixDirAliases.nixosConfigurations = [ "nixos" ];` is set which means
"nixos" can be used instead of "nixosConfigurations" for loading the files as
described above.

All options except for `nixDir` and `_module` can be configured this way.

To apply transformations on the output of an autoloaded directory, you can use
`option/default.nix` and load the directory with `flakelight.importDir`.

If you add a new config type that should be loaded as paths instead of imported,
such as configs for Nix modules, add them to the `nixDirPathAttrs` option. This
is already set for built-in module options. When options whose names are in
`nixDirPathAttrs` are loaded as a directory, `flakelight.importDirPaths` is used
instead of `flakelight.importDir`.

You may set `nixDir` to null to not load from any directory.

### outputs

```
Type: AttrSet | (ModuleArgs -> AttrSet)
```

The `outputs` option allows you to directly configure flake outputs. This should
be used for porting or for configuring output attrs not otherwise supported by
Flakelight.

The option value may be an attrset or a function that takes `moduleArgs` and
returns and attrset.

To add a `example.test` output to your flake you could do the following:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      outputs = {
        example.test = "hello";
      };
    };
}
```

With the above, `nix eval .#example.test` will output "hello".

This can be used to configure any output, for example directly setting an
overlay (though this can be configured with the `overlays` option):

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      outputs.overlays.clang = final: prev: { stdenv = final.clangStdenv; };
    };
}
```

### perSystem

```
Type: Pkgs -> AttrSet
```

The `perSystem` option allows you to directly configure per-system flake
outputs, and gives you access to packages. This should be used for porting or
for configuring output attrs not otherwise supported by Flakelight.

To add `example.${system}.test` outputs to your flake, you could do the
following:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      perSystem = pkgs: {
        example.test = pkgs.writeShellScript "test" "echo hello";
      };
    };
}
```

The above, with default systems, will generate `example.x86_64-linux.test` and
`example.aarch64-linux.test` attributes.

### nixpkgs.config

```
Type: AttrSet
```

This allows you to pass configuration options to the Nixpkgs instance used for
building packages and calling perSystem.

For example, to allow building broken or unsupported packages, you can set the
option as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      nixpkgs.config = { allowBroken = true; allowUnsupportedSystem = true; };
    };
}
```

### nixpkgs.overlays

```
Type: [Overlay]
```

This allows you to apply overlays to the Nixpkgs instance used for building
packages and calling perSystem. `withOverlays` is a more flexible version of
this option.

### withOverlays

```
Type: [Overlay] | Overlay | (ModuleArgs -> [Overlay])
```

This allows you to apply overlays to the Nixpkgs instance used for building
packages and calling perSystem.

It can be set to either a list of overlays or a single overlay.

For example, to apply the Emacs overlay and change the Zig version, you can set
the option as follows:

```nix
{
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
  };
  outputs = { flakelight, emacs-overlay, ... }:
    flakelight ./. {
      withOverlays = [
        emacs-overlay.overlays.default
        (final: prev: { zig = final.zig_0_9; })
      ];
    };
}
```

You can use the values from the overlays with other options:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      withOverlays = final: prev: { testValue = "hi"; };

      package = { writeShellScript, testValue }:
        writeShellScript "test" "echo ${testValue}";
    };
}
```

### nixpkgs.patches

```
Type: [path]
```

This allows you to apply patches to the Nixpkgs instance used for building
packages and calling perSystem.

For example, to apply a patch in the same directory named `fix-hello.patch`:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      nixpkgs.patches = [ ./fix-hello.patch ];
    };
}
```

### packages

```
Types:
  package: PackageDef
  packages: (AttrsOf PackageDef) | (ModuleArgs -> (AttrsOf PackageDef))
  pname: Str
```

The `package` and `packages` options allow you to add packages. These are
exported in the `packages.${system}` outputs, are included in
`overlays.default`, and have build checks in `checks.${system}`.

`package` can be set to a package definition, and will set `packages.default`.

`packages` can be set to attrs of package definitions. If it is a function, it
will additionally get a `system` arg in addition to module args, to allow
conditionally including package definitions depending on the system.

By default, the `packages.default` package's name (its attribute name in the
package set and overlay) is automatically determined from the derivation's
`pname`. In order to use a different attribute name from the package pname, to
set it in cases where it cannot be automatically determined, or to speed up
uncached evaluation, the flakelight `pname` option can be set.

To set the default package, you can set the options as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      package = { stdenv }:
        stdenv.mkDerivation {
          pname = "pkg1";
          version = "0.0.1";
          src = ./.;
          installPhase = "make DESTDIR=$out install";
        };
    };
}
```

The above will export `packages.${system}.default` attributes, add `pkg1` to
`overlays.default`, and export `checks.${system}.packages-default`.

You can also instead just directly set `packages.default`.

To set multiple packages, you can set the options as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      packages = {
        default = { stdenv }:
          stdenv.mkDerivation {
            name = "pkg1";
            src = ./.;
            installPhase = "make DESTDIR=$out install";
          };
        pkg2 = { stdenv, pkg1, pkg3 }:
          stdenv.mkDerivation {
            name = "hello-world";
            src = ./pkg2;
            nativeBuildInputs = [ pkg1 pkg3 ];
            installPhase = "make DESTDIR=$out install";
          };
        pkg3 = { stdenv }:
          stdenv.mkDerivation {
            name = "hello-world";
            src = ./pkg3;
            installPhase = "make DESTDIR=$out install";
          };
      };
    };
}
```

The above will export `packages.${system}.default`, `packages.${system}.pkg2`,
`packages.${system}.pkg3` attributes, add `pkg1`, `pkg2`, and `pkg3` to
`overlays.default`, and export corresponding build checks.

To use the first example, but manually specify the package name:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      pname = "pkgs-attribute-name";
      package = { stdenv }:
        stdenv.mkDerivation {
          pname = "package-name";
          version = "0.0.1";
          src = ./.;
          installPhase = "make DESTDIR=$out install";
        };
    };
}
```

To add a package only for certain systems, you can take `system` as an arg as
follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      packages = { system, ... }: if (system == "x86_64-linux") then {
        pkg1 = { stdenv }:
          stdenv.mkDerivation {
            name = "pkg1";
            src = ./.;
            installPhase = "make DESTDIR=$out install";
          };
      } else { };
    };
}
```

### devShell

```
Type:
  devShell: Cfg | (Pkgs -> Cfg) | PackageDef | Derivation | (Pkgs -> Derivation)
  Cfg.packages: [Derivation] | (Pkgs -> [Derivation])
  Cfg.inputsFrom: [Derivation] | (Pkgs -> [Derivation])
  Cfg.shellHook: Str | (Pkgs -> Str)
  Cfg.env: (AttrsOf Str) | (Pkgs -> (AttrsOf Str))
  Cfg.stdenv: Stdenv | (Pkgs -> Stdenv)
```

The devshell options allow you to configure `devShells.${system}.default`. It is
split up into options in order to enable multiple modules to contribute to its
configuration.

`devShell` can alternatively be set to a package definition or derivation, which
is then used as the default shell, overriding other options.

`devShell` can also be set to a function that takes the package set and returns
an attrSet of the devShell configuration options or a derivation.

The options available are as follows:

`devShell.packages` is a list of packages to add to the shell. It can optionally
be a function taking the package set and returning such a list.

`devShell.inputsFrom` is a list of packages whose deps should be in the shell.
It can optionally be a function taking the package set and returning such a
list.

`devShell.shellHook` is a string that provides bash code to run in shell
initialization. It can optionally be a function taking the package set and
returning such a string.

`devShell.hardeningDisable` is a list of hardening options to disable. Setting
it to `["all"]` disables all Nix hardening.

`devShell.env` is for setting environment variables in the shell. It is an
attribute set mapping variables to values. It can optionally be a function
taking the package set and returning such an attribute set.

`devShell.stdenv` is the stdenv package used for the shell. It can optionally be
a function takeing the package set and returning the stdenv to use.

For example, these can be configured as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShell = pkgs: {
        # Include build deps of emacs
        inputsFrom = [ pkgs.emacs ];
        # Add coreutils to the shell
        packages = [ pkgs.coreutils ];
        # Add shell hook. Can be a function if you need packages
        shellHook = ''
          echo Welcome to example shell!
        '';
        # Set an environment var. `env` can be an be a function
        env.TEST_VAR = "test value";
        stdenv = pkgs.clangStdenv;
      };
    };
}
```

The above exports `devShells.${system}.default` outputs.

To add the build inputs of one of your packages, you can do as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      package = { stdenv }:
        stdenv.mkDerivation {
          pname = "pkg1";
          version = "0.0.1";
          src = ./.;
          installPhase = "make DESTDIR=$out install";
        };
      devShell = {
        inputsFrom = pkgs: [ pkgs.pkg1 ];
      };
    };
}
```

To override the devShell, you can use a package definition as such:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShell = { mkShell, hello }: mkShell {
        packages = [ hello ];
      };
    };
}
```

### devShells

```
Type:
  devShells: (AttrsOf (PackageDef | Cfg | (Pkgs -> Cfg)) |
             (ModuleArgs -> (AttrsOf (PackageDef | Cfg | (Pkgs -> Cfg))))
  Cfg.packages: [Derivation] | (Pkgs -> [Derivation])
  Cfg.inputsFrom: [Derivation] | (Pkgs -> [Derivation])
  Cfg.shellHook: Str | (Pkgs -> Str)
  Cfg.env: (AttrsOf Str) | (Pkgs -> (AttrsOf Str))
  Cfg.stdenv: Stdenv | (Pkgs -> Stdenv)
```

The `devShells` option allows you to set additional `devShell` outputs. The
values each shell can be set to are the same as described above for the
`devShell` option.

For example, using the configuration options:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShells.testing = {
        packages = pkgs: [ pkgs.coreutils ];
        env.TEST_VAR = "in testing shell";
      };
    };
}
```

For example, using a package definition:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShells.testing = { mkShell, coreutils }:
        mkShell {
          packages = [ coreutils ];
          env.TEST_VAR = "in testing shell";
        };
    };
}
```

The above flakes export `devShells.${system}.testing` outputs.

### overlays

```
Types:
  overlay: Overlay
  overlays: (AttrsOf Overlay) | (ModuleArgs -> (AttrsOf Overlay)
```

The `overlay` and `overlays` options allow you to configure `overlays` outputs.

Multiple provided overlays for an output are merged.

The `overlay` option adds the overlay to `overlays.default`.

The `overlays` option allows you to add overlays to `overlays` outputs.

For example, to add an overlay to `overlays.default`, do the following:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      overlay = final: prev: { testValue = "hello"; };
    };
}
```

The above results in `overlays.default` output containing testValue.

To configure other overlays:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      overlays.cool = final: prev: { testValue = "cool"; };
    };
}
```

The above results in a `overlays.cool` output.

### checks

```
Types:
  checks: (AttrsOf Check) | (Pkgs -> (AttrsOf Check))
  Check: Str | (Pkgs -> Str) | Derivation | (Pkgs -> Derivation)
```

The `checks` option allows you to add checks for `checks.${system}` attributes.

It can be set to an attribute set of checks, which can be functions,
derivations, or strings.

If a check is a derivation, it will be used as is.

If a check is a string, it will be included in a bash script that runs it in a
copy of the source directory, and succeeds if the no command in the string
errored.

If a check is a function, it will be passed packages, and should return one of
the above.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      checks = {
        # Check that succeeds if the source contains the string "hi"
        hi = { rg, ... }: "${rg}/bin/rg hi";
        # Check that emacs builds
        emacs = pkgs: pkgs.emacs;
      };
    };
}
```

### apps

```
Types:
  app: App'
  apps: (AttrsOf App') | (Pkgs -> (AttrsOf App'))
  App': Str | (Pkgs -> Str) | App | (Pkgs -> App)
```

The `app` and `apps` options allow you to set `apps.${system}` outputs.

`apps` is an attribute set of apps or a function that takes packages and returns
an attribute set of apps. If the app value is a function, it is passed packages.
If the app value or function result is a string, it is converted to an app.

`app` sets `apps.default`.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      apps = {
        emacs = pkgs: "${pkgs.emacs}/bin/emacs";
        bash = pkgs: { type = "app"; program = "${pkgs.bash}/bin/bash"; };
      };
    };
}
```

Alternatively, the above can be written as:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      apps = { emacs, bash, ... }: {
        emacs = "${emacs}/bin/emacs";
        bash = { type = "app"; program = "${bash}/bin/bash"; };
      };
    };
}
```

### templates

```
Types:
  template: Template | (ModuleArgs -> Template)
  templates: (AttrsOf (Template | (ModuleArgs -> Template))) |
             (ModuleArgs -> (AttrsOf (Template | (ModuleArgs -> Template))))
```

The `template` and `templates` options allow you to set `templates` outputs.

`templates` is an attribute set to template values.

`template` sets `templates.default`.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      templates.test-template = {
        path = ./test;
        description = "test template";
      };
    };
}
```

### legacyPackages

```
Type: Pkgs -> Pkgs
```

The `legacyPackages` option allows you to configure the flake's `legacyPackages`
output. It can be set to a function that takes the package set and returns the
package set to be used as the corresponding system's legacyPackages output.

For example:

```nix
{
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = { flakelight, nixpkgs, ... }:
    flakelight ./. {
      legacyPackages = pkgs: nixpkgs.legacyPackages.${pkgs.system};
    };
}
```

To export the package set used for calling package definitions and other options
that take functions passed the package set, you can do the following:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      legacyPackages = pkgs: pkgs;
    };
}
```

### formatter

```
Type: Pkgs -> Derivation
```

The `formatter` option allows you to set `formatter.${system}` outputs. It can
be set to a function that takes packages and returns the package to use. This
overrides the `formatters` functionality described below though, so for
configuring formatters for a file type, you likely want to use `formatters`
instead.

For example, to use a custom formatting command:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      formatter = pkgs: pkgs.writeShellScriptBin "format-script" ''
        # Perform formatting (`nix fmt` calls the script with `.` as arg)
      '';
    };
}
```

### formatters

```
Type: (AttrsOf Str) | (Pkgs -> (AttrsOf Str))
```

The `formatters` option allows you to configure formatting tools that will be
used by `nix fmt`. If formatters are set, Flakelight will export
`formatter.${system}` outputs which apply all the configured formatters.

By default, `nix` files are formatted with `nixpkgs-fmt` and `md`, `json`, and
`yml` files are formatted with `prettier`.

To disable default formatters, set the `flakelight.builtinFormatters` option to
false.

You can set `formatters` to an attribute set, for which the keys are a file name
pattern and the value is the corresponding formatting command. `formatters` can
optionally be a function that takes packages and returns the above.

Formatting tools should be added to `devShell.packages`; this enables easier use
as described below, as well as allowing flake users to use the tools directly
when in the devShell.

Formatters can be set to a plain string like `"zig fmt"` or a full path like
`"${pkgs.zig}/bin/zig fmt"`. Formatters set as plain strings have access to all
packages in `devShell.packages`.

If building the formatter is slow due to building devShell packages, use full
paths for the formatters; the devShell packages are only included if a
formatting option is set to a plain string.

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShell.packages = pkgs: [ pkgs.rustfmt pkgs.zig ];
      formatters = {
        "*.rs" = "rustfmt";
        "*.zig" = "zig fmt";
      };
    };
}
```

### bundlers

```
Types:
  bundler: Bundler | (Pkgs -> Bundler)
  bundlers: (AttrsOf (Bundler | (Pkgs -> Bundler))) |
            (ModuleArgs -> (AttrsOf (Bundler | (Pkgs -> Bundler))))
```

The `bundler` and `bundlers` options allow you to set `bundlers.${system}`
outputs.

Each bundler value can be either a bundler function or a function that takes the
package set and returns a bundler function.

`bundlers` is an attribute set of bundler values or a function that takes
packages and returns an attribute set of bundler values.

`bundler` sets `bundlers.default`.

For example, a bundler that returns the passed package:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      bundler = x: x;
    };
}
```

As another example, a bundler that always returns `hello`:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      bundlers = { hello, ... }: {
        hello = x: hello;
      };
    };
}
```

To write the above using autoloads, can use the following:

```nix
# nix/bundlers/hello.nix
{ hello, ... }: x: hello;
```

### nixosConfigurations

```
Type: (AttrsOf (NixOSArgs | NixOSConfig |
        (ModuleArgs -> (NixOSArgs | NixOSConfig)))) |
      (ModuleArgs -> (AttrsOf (NixOSArgs | NixOSConfig |
                       (ModuleArgs -> (NixOSArgs | NixOSConfig)))))
```

The `nixosConfigurations` attribute lets you set outputs for NixOS systems and
home-manager users.

It should be set to an attribute set. Each value should be a set of
`nixpkgs.lib.nixosSystem` args, the result of calling `nixpkgs.lib.nixosSystem`,
or a function that takes `moduleArgs` and returns one of the prior.

When using a set of `nixpkgs.lib.nixosSystem` args, NixOS modules will have
access to a `flake` module arg equivalent to `moduleArgs` plus `inputs'` and
`outputs'`. Flakelight's pkgs attributes, `withOverlays`, and `packages` will
also be available in the NixOS instance's pkgs, and Flakelight's `nixpkgs`
config will apply to it as well.

When using the result of calling `nixpkgs.lib.nixosSystem`, the
`config.propagationModule` value can be used as a NixOS module to gain the above
benefits.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, config, ... }: {
      nixosConfigurations.test-system = {
        modules = [{
          nixpkgs.hostPlatform.system = "x86_64-linux";
          system.stateVersion = "25.05";
        }];
      };
    });
}
```

### homeConfigurations

```
Type: (AttrsOf (HomeArgs | HomeConfig |
        (ModuleArgs -> (HomeArgs | HomeConfig)))) |
      (ModuleArgs -> (AttrsOf (HomeArgs | HomeConfig |
                       (ModuleArgs -> (HomeArgs | HomeConfig)))))
```

The `homeConfigurations` attribute lets you set outputs for NixOS systems and
home-manager users.

It should be set to an attribute set. Each value should be a set of
`home-manager.lib.homeManagerConfiguration` args, the result of calling
`home-manager.lib.homeManagerConfiguration`, or a function that takes
`moduleArgs` and returns one of the prior.

When using a set of `homeManagerConfiguration` args, it is required to include
`system` (`pkgs` does not need to be included), and `inputs.home-manager` must
be set. home-manager modules will have access to a `flake` module arg equivalent
to `moduleArgs` plus `inputs'` and `outputs'`. Flakelight's pkgs attributes,
`withOverlays`, and `packages` will also be available in the home-manager
instance's pkgs, and Flakelight's `nixpkgs` config will apply to it as well.

When using the result of calling `homeManagerConfiguration`, the
`config.propagationModule` value can be used as a home-manager module to gain
the above benefits.

For example:

```nix
{
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    home-manger.url = "github:nix-community/home-manager";
  };
  outputs = { flakelight, home-manager, ... }@inputs:
    flakelight ./. ({ config, ... }: {
      inherit inputs;
      homeConfigurations.username = {
        system = "x86_64-linux";
        modules = [{ home.stateVersion = "24.05"; }];
      };
    });
}
```

### nixosModules, homeModules, and flakelightModules

```
Types:
  nixosModule: Module
  nixosModules: (AttrsOf Module) | (ModuleArgs -> (AttrsOf Module))
  homeModule: Module
  homeModules: (AttrsOf Module) | (ModuleArgs -> (AttrsOf Module))
  flakelightModule: Module
  flakelightModules: (AttrsOf Module) | (ModuleArgs -> (AttrsOf Module))
```

The `nixosModules`, `homeModules`, and `flakelightModules` options allow you to
configure the corresponding outputs.

The `nixosModule`, `homeModule`, and `flakelightModule` options set the
`default` attribute of the corresponding above option.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, ... }: {
      nixosModule = { system, lib, pkgs, ... }: {
        # nixos module configuration
      };
    });
}
```

These can be paths, which is preferred as it results in better debug output:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, ... }: {
      nixosModule = ./module.nix;
      homeModules = {
        default = ./home.nix;
        emacs = ./emacs.nix;
      }
    });
}
```

### lib

```
Type: AttrSet | (ModuleArgs -> AttrSet)
```

The `lib` option allows you to configure the flake's `lib` output.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      lib = {
        addFive = x: x + 5;
        addFour = x: x + 4;
      };
    };
}
```

### functor

```
Type: Outputs -> Any -> Any
```

The `functor` option allows you to make your flake callable.

If it is set to a function, that function will be set as the `__functor`
attribute of your flake outputs.

Flakelight uses it so that calling your `flakelight` input calls
`flakelight.lib.mkFlake`.

As an example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      outputs.testvalue = 5;
      functor = self: x: x + self.testvalue;
    }
}
```

With the above flake, another flake that has imports it with the name `addFive`
would be able to call `addFive 4` to get 9.

### meta

```
Types:
  description: Str
  license: Str | [Str]
```

The following options are available for configuring the meta attributes of the
default package for supported modules (such as flakelight-rust or
flakelight-zig) or for use in your own packages through the `defaultMeta` pkgs
value.

`description` allows setting the package description. By default it uses the
flake description, if found.

`license` lets you set the license or license. It may be a single string or list
of strings. These strings may be Spdx license identifiers or Nixpkgs license
attribute names.

### flakelight

```
Types:
  flakelight.editorconfig: Bool
  flakelight.builtinFormatters: Bool
```

This option has options for configuring Flakelight's defaults.

`flakelight.editorconfig` can be set to false to disable the editorconfig check
that is added if editorconfig configuration is detected.

`flakelight.builtinFormatters` can be set to false to disable the default
formatting configuration.
