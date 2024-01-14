# API Guide

## lib

This section covers important functions available in Flakelight's lib attribute.

### mkFlake

The outputs of a flake using Flakelight are created using the `mkFlake` function.
When called directly, Flakelight invokes `mkFlake`, as follows:

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
- `moduleArgs`: All of the above arguments (passed to auto-loaded files)

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

The `inputs` option allows setting the flake inputs used by modules. To set the
nixpkgs used for building outputs, you can pass your flake inputs in as follows:

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flakelight.url = "github:nix-community/flakelight";
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
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flakelight.url = "github:nix-community/flakelight";
  };
  outputs = { flakelight, nixpkgs, ... }:
    flakelight ./. {
      inputs.nixpkgs = nixpkgs;
    };
}
```

### systems

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

### outputs

The `outputs` option allows you to directly configure flake outputs. This should
be used for porting or for configuring output attrs not otherwise supported by
Flakelight.

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

This allows you to pass configuration options to the nixpkgs instance used for
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

### withOverlays

This allows you to apply overlays to the nixpkgs instance used for building
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

### packages

The `package` and `packages` options allow you to add packages. These are
exported in the `packages.${system}` ouputs, are included in `overlays.default`,
and have build checks in `checks.${system}`.

`package` can be set to a package definition, and will set `packages.default`.

`packages` can be set to attrs of package definitions.

By default, the `packages.default` package's name (its attribute name in
the package set and overlay) is automatically determined from the derivation's
`pname`. In order to use a different attribute name from the package pname,
to set it in cases where it cannot be automatically determined, or to speed up
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

### devShell

The devshell options allow you to configure `devShells.${system}.default`. It is
split up into options in order to enable multiple modules to contribute to its
configuration.

The first three correspond to `mkShell` arguments.

`devShell.packages` is a function that takes the package set and returns a list
of packages to add to the shell.

`devShell.inputsFrom` is a function that takes the package set and returns a
list of packages whose deps should be in the shell.

`devShell.shellHook` is a string that provides bash code to run in shell
initialization. It can optionally be a function to such a string in order to
access packages.

`devShell.env` is for setting environment variables in the shell. It is an
attribute set mapping variables to values. It can optionally be a function to
such an attribute set in order to access packages.

`devShell.stdenv` allows changing the stdenv used for the shell. It is a
function that takes the package set and returns the stdenv to use.

`devShell` can alternatively be set to a package definition, which is then used
as the default shell, overriding the above options.

For example, these can be configured as follows:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShell = {
        # Include build deps of emacs
        inputsFrom = pkgs: [ pkgs.emacs ];
        # Add coreutils to the shell
        packages = pkgs: [ pkgs.coreutils ];
        # Add shell hook. Can be a function if you need packages
        shellHook = ''
          echo Welcome to example shell!
        '';
        # Set an environment var. `env` can be an be a function
        env.TEST_VAR = "test value";
        stdenv = pkgs: pkgs.clangStdenv;
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

### devShells

The `devShells` option allows you to set additional `devShell` outputs.

For example:

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

The above exports `devShells.${system}.testing` outputs.

### overlays

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

The `app` and `apps` options allow you to set `apps.${system}` outputs.

`apps` is an attribute set of apps or a function that takes packages and returns
an attribute set of apps. If the app value is not an app, it is converted to a
string and set as the program attr of an app. If it is a function, it is passed
packages.

`app` sets `apps.default`.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      apps = {
        shell = "/bin/sh";
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
        shell = "/bin/sh";
        emacs = "${emacs}/bin/emacs";
        bash = { type = "app"; program = "${bash}/bin/bash"; };
      };
    };
}
```

### templates

The `template` and `templates` options allow you to set `templates`
outputs.

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

### formatter

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

Formatting tools should be added to `devShell.packages` and all packages in
`devShell.packages` will be available for formatting commands.

For example, to set Rust and Zig formatters:

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

The `nixosConfigurations` attribute lets you set outputs for NixOS systems and
home-manager users.

It should be set to an attribute set. Each value should be a set of
`nixpkgs.lib.nixosSystem` args, the result of calling `nixpkgs.lib.nixosSystem`,
or a function that takes `moduleArgs` and returns one of the prior.

When using a set of `nixpkgs.lib.nixosSystem` args, NixOS modules will have
access to a `flake` module arg equivalent to `moduleArgs` plus `inputs'` and
`outputs'`. Flakelight's pkgs attributes, `withOverlays`, and `packages` will
also be available in the NixOS instance's pkgs.

When using the result of calling `nixpkgs.lib.nixosSystem`, the
`config.propogationModule` value can be used as a NixOS module to gain the above
benefits.

For example:

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. ({ lib, config, ... }: {
      nixosConfigurations.test-system = {
        system = "x86_64-linux";
        modules = [{ system.stateVersion = "24.05"; }];
      };
    });
}
```

### homeConfigurations

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
instance's pkgs.

When using the result of calling `homeManagerConfiguration`, the
`config.propogationModule` value can be used as a home-manager module to gain
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

The following options are available for configuring the meta attributes of the
default package for supported modules (such as flakelight-rust or
flakelight-zig) or for use in your own packages through the `defaultMeta` pkgs
value.

`description` allows setting the package description. By default it uses the
flake description, if found.

`license` lets you set the license or license. It may be a single string or list
of strings. These strings may be Spdx license identifiers or nixpkgs license
attribute names.

### nixDir

The `nixDir` option is `./nix` by default and sets which directory to use to
automatically load nix files for flake attributes from.

For a given supported attribute attr, the following is checked in order:

- If `${nixDir}/attr.nix` exists, it is imported as the value
- Else if `${nixDir}/attr` is a directory with a `default.nix`, it is imported
- Else if `${nixDir}/attr` is a directory, it results in an attrset with an
  entry for each nix file in the directory whose values are the corresponding
  files imported

Many of the values can additionally be a function that takes module args to
enable use of module args from imported files. For values without module args,
these values can be obtained from the pkg set as `moduleArgs` or directly.

To enable using a directory for an attrset that includes a `default` attribute,
attr names can be escaped with an underscore. For example,
`${nixDir}/nix/packages/_default.nix` will be loaded as `packages.default`.

The following options can be autoloaded with optional module args:

- outputs
- packages
- overlays
- devShell
- devShells
- tempalte
- templates
- nixosModules
- nixosConfigurations
- homeModules
- homeConfigurations
- flakelightModules
- lib

The following options can be autoloaded (no module args):

- perSystem
- withOverlays
- package
- app
- apps
- checks
- formatters
- nixosModule
- homeModule
- flakelightModule
- functor

### flakelight

This option has options for configuring Flakelight's defaults.

`flakelight.editorconfig` can be set to false to disable the editorconfig
check that is added if editorconfig configuration is detected.

`flakelight.builtinFormatters` can be set to false to disable the default
formatting configuration.
