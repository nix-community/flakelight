# Flakelight

A modular Nix flake framework for simplifying flake definitions.

## Goals

- Minimize boilerplate needed for flakes
- Support straightforward configuration of all vanilla flake attributes
- Allow sharing common configuration using modules
- What can be done automatically, should be
- Provide good defaults, but let them be changed/disabled

## Features

- Handles generating per-system attributes
- Extensible using the module system
- Given package definitions, generates package and overlay outputs
- Automatically import attributes from nix files in a directory (default `./nix`)
- Builds formatter outputs that can format multiple file types
- Provides outputs/perSystem options for easy migration

## Documentation

See the [API docs](./API_GUIDE.md) for available options and example usage.

## Additional modules

The following modules are also available:

- [flakelight-rust][] for Rust projects
- [flakelight-zig][] for Zig projects
- [flakelight-elisp][] for flakes providing Emacs lisp package(s)
- [flakelight-darwin][] for nix-darwin configs

[flakelight-rust]: https://github.com/accelbread/flakelight-rust
[flakelight-zig]: https://github.com/accelbread/flakelight-zig
[flakelight-elisp]: https://github.com/accelbread/flakelight-elisp
[flakelight-darwin]: https://github.com/cmacrae/flakelight-darwin

## Contact

Feel free to ask for help or other questions in the issues/discussions, or reach
out on Matrix at [#flakelight:nixos.org][matrix-flakelight].

[matrix-flakelight]: https://matrix.to/#/#flakelight:nixos.org

## Examples

### Shell

The following is an example flake.nix for a devshell, using the passed in
nixpkgs. It outputs `devShell.${system}.default` attributes for each configured
system. `systems` can be set to change configured systems from the default.

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShell.packages = pkgs: [ pkgs.hello pkgs.coreutils ];
    };
}
```

With this flake, calling `nix develop` will make `hello` and `coreutils`
available.

To use a different nixpkgs, you can instead use:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flakelight.url = "github:nix-community/flakelight";
  };
  outputs = { flakelight, ... }@inputs:
    flakelight ./. {
      inherit inputs;
      devShell.packages = pkgs: [ pkgs.hello pkgs.coreutils ];
    };
}
```

### Rust package

The following is an example flake for a Rust project using `flakelight-rust`,
invoked by using `flakelight-rust`'s wrapper.
Package metadata is taken from the project's `Cargo.toml`.

```nix
{
  inputs.flakelight-rust.url = "github:accelbread/flakelight-rust";
  outputs = { flakelight-rust, ... }: flakelight-rust ./. { };
}
```

The above flake exports the following:

- Per-system attributes for default systems (`x86_64-linux` and `aarch64-linux`)
- `packages.${system}.default` attributes for each system
- `overlays.default` providing an overlay with the package (built with the
  applied pkg set's dependencies)
- `devShells.${system}.default` that provides `rust-analyzer`, `cargo`, `clippy`,
  `rustc`, and `rustfmt` as well as sets `RUST_SRC_PATH`
- `checks.${system}.${check}` attributes for build, test, clippy, and formatting
  checks
- `formatter.${system}` with additional support for formatting Rust files

Equivalently, you can just import the `flakelight-rust` module as follows:

```nix
{
  inputs = {
    flakelight.url = "github:nix-community/flakelight";
    flakelight-rust.url = "github:accelbread/flakelight-rust";
  };
  outputs = { flakelight, flakelight-rust, ... }: flakelight ./. {
    imports = [ flakelight-rust.flakelightModules.default ];
  };
}
```

See [flakelight-rust.nix][flakelight-rust] to see how you could configure it
without the module.

[flakelight-rust]: https://github.com/accelbread/flakelight-rust/blob/master/flakelight-rust.nix

### C application

The following example flake is for a C project with a simple `make` setup.

```nix
{
  description = "My C application.";
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      license = "AGPL-3.0-or-later";

      package = { stdenv, defaultMeta }:
        stdenv.mkDerivation {
          name = "hello-world";
          src = ./.;
          installPhase = ''
            runHook preInstall
            make DESTDIR=$out install
            runHook postInstall
          '';
          meta = defaultMeta;
        };

      devShell.packages = pkgs: with pkgs; [ clang-tools coreutils ];

      formatters = {
        "*.h" = "clang-format -i";
        "*.c" = "clang-format -i";
      }
    };
}
```

This flake exports the following:

- Per-system attributes for default systems (`x86_64-linux` and `aarch64-linux`)
- `packages.${system}.default` attributes for each system, with license and
  description set
- `overlays.default` providing an overlay with the package (built with the
  applied pkg set's dependencies)
- `devShells.${system}.default` that provides `clang-tools` and `coreutils`
- `checks.${system}.${check}` attributes for build and formatting checks.
- `formatter.${system}` with additional support for formatting `c` and `h` files
  with `clang-format`

### C application using autoloads

The above example can instead use the autoload directory feature for the package
like the following. Most attributes can be autoloaded.

`./flake.nix`:

```nix
{
  description = "My C application.";
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      license = "AGPL-3.0-or-later";

      devShell.packages = pkgs: with pkgs; [ clang-tools coreutils ];

      formatters = {
        "*.h" = "clang-format -i";
        "*.c" = "clang-format -i";
      }
    };
}
```

`./nix/packages/_default.nix`:

```nix
{ stdenv, defaultMeta }:
stdenv.mkDerivation {
  name = "hello-world";
  src = ./.;
  installPhase = ''
    runHook preInstall
    make DESTDIR=$out install
    runHook postInstall
  '';
  meta = defaultMeta;
}
```

A leading underscore in filename is stripped (default needs to be escaped to not
conflict with dir import).

## Differences from flake-parts

*Note: Text below taken from [discourse post](https://discourse.nixos.org/t/flakelight-a-new-modular-flake-framework/32395/3)*

Here are some of the differences:

### Per-system attributes

Flake-parts has perSystem modules which contain per-system options, while Flakelight has regular options which can be functions that are passed the set of packages.

For example:

Flake-parts:

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { pkgs, ... }: {
        apps.default.program = "${pkgs.hello}/bin/hello";
      };
    };
}
```

Flakelight:

```nix
{
  inputs.flakelight.url = "github:accelbread/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      app = pkgs: "${pkgs.hello}/bin/hello";
    };
}
```

### Shortcuts for default

There are options to set default outputs; in the above example, app sets `apps.default`. This lowers boilerplate for flakes that just set default outputs. You can still set other app outputs or directly use apps.default.

### Overlays actually use your deps

If a dependency flake using Flake-parts has a package A that depends on package B in its overlay, and a user applies that overlay to their nixpkgs, A will use B from the dependency flake’s nixpkgs. 
If that flake were using Flakelight, A would use B from the user’s nixpkgs, like how overlays usually work.

If a user actually wanted to use the flake’s packages with it’s dependencies, they can already do that with `_: prev: flake.packages.${prev.system}`.

### Autoload files from ./nix

Flakelight options can be automatically read from files in ./nix. 
For example you could have files for ./nix/packages/a.nix and ./nix/packages/b.nix to define packages a and b, or just have a ./nix/packages.nix that defines both.

The directory to load from can also be changed.

### Using overlays from other flakes

Flake-parts:
```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, emacs-overlay, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { pkgs, system, ... }: {
        _module.args.pkgs = import nixpkgs { 
            inherit system;
            overlays = [ emacs-overlay.overlays.default ]; };
        };
    };
}
```

Flakelight:
```nix
{
  inputs.flakelight.url = "github:accelbread/flakelight";
  outputs = { flakelight, emacs-overlay, ... }:
    flakelight ./. {
      withOverlays = [ emacs-overlay.overlays.default ];
    };
}
```

### Inputs

In Flake-parts, inputs is a separate parameter. In Flakelight, it is a normal option. 
Also, defaults for all used dependencies are provided, so you can leave it unset.

### Src

Flakelight takes an src argument that your modules can use to automatically set up packages and attributes. 
For example, Flakelight-rust derives flake outputs from src + /Cargo.toml. As another example, if your repo has a .editorconfig file, an editorconfig check will be added.

### Packages are defined like in nixpkgs

```nix
{
  inputs.flakelight.url = "github:accelbread/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      package = { stdenv, cmake, ninja }:
        stdenv.mkDerivation {
          pname = "pkg1";
          version = "0.0.1";
          src = ./.;
          nativeBuildInputs = [ cmake ninja ];
        };
    };
}
```

Alternatively using autoloaded files:

*flake.nix:*
```nix
{
  inputs.flakelight.url = "github:accelbread/flakelight";
  outputs = { flakelight, ... }: flakelight ./. { };
}
```

*nix/package.nix:*

```nix
{ stdenv, cmake, ninja, src }:
stdenv.mkDerivation {
  pname = "pkg1";
  version = "0.0.1";
  inherit src;
  nativeBuildInputs = [ cmake ninja ];
};
```

With Flake-parts, this would be:

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { pkgs, ... }: {
        packages.default =
          let
            inherit (pkgs) stdenv cmake ninja;
          in
          stdenv.mkDerivation {
            pname = "pkg1";
            version = "0.0.1";
            src = ./.;
            nativeBuildInputs = [ cmake ninja ];
          };
    };
  };
}
```

Flakelight’s src parameter also lets other files and modules easily access the flake’s root dir, which an external module could not in Flake-parts.
With Flakelight, since packages are functions, it can also automatically generate a correct overlay.

### No empty outputs

Flake-parts creates empty outputs; for example if you don’t have any packages, it will create a packages output that is an empty set. Flakelight does not do this.

### Multi-language formatter

Flakelight has options to define formatters for different file types, that can be set by different modules. 
All configured formatters will be combined to provide a `formatter.${system}` that formats each configured file type with its corresponding formatter.

### Designed to enable modules to do most of the work

For example, here is a flake for a Rust package:
```nix
{
  inputs = {
    flakelight.url = "github:accelbread/flakelight";
    flakelight-rust.url = "github:accelbread/flakelight-rust";
  };
  outputs = { flakelight, flakelight-rust, ... }: flakelight ./. {
    imports = [ flakelight-rust.flakelightModules.default ];
  };
}
```

It exports the following:
- Per-system attributes for default systems (`x86_64-linux` and `aarch64-linux`)
- `packages.${system}.default` attributes for each system
- `overlays.default` providing an overlay with the package (built with the applied pkg set’s dependencies)
- `devShells.${system}.default` that provides `rust-analyzer`, `cargo`, `clippy`, `rustc`, and `rustfmt` as well as sets `RUST_SRC_PATH`
- `checks.${system}.${check}` attributes for build, test, clippy, and formatting checks
- `formatter.${system}` will also format Rust files with `rustfmt`.

The above flake can also be written equivalently as:

```nix
{
  inputs.flakelight-rust.url = "github:accelbread/flakelight-rust";
  outputs = { flakelight-rust, ... }: flakelight-rust ./. { };
}
```
