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
- Automatically import attributes from nix files in a directory (default
  `./nix`)
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
- [flakelight-haskell][] for Haskell projects

[flakelight-rust]: https://github.com/accelbread/flakelight-rust
[flakelight-zig]: https://github.com/accelbread/flakelight-zig
[flakelight-elisp]: https://github.com/accelbread/flakelight-elisp
[flakelight-darwin]: https://github.com/cmacrae/flakelight-darwin
[flakelight-haskell]: https://github.com/hezhenxing/flakelight-haskell

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
invoked by using `flakelight-rust`'s wrapper. Package metadata is taken from the
project's `Cargo.toml`.

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
- `devShells.${system}.default` that provides `rust-analyzer`, `cargo`,
  `clippy`, `rustc`, and `rustfmt` as well as sets `RUST_SRC_PATH`
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

[flakelight-rust]:
  https://github.com/accelbread/flakelight-rust/blob/master/flakelight-rust.nix

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

## Related Resources

- [Comparison to flake-parts](https://discourse.nixos.org/t/flakelight-a-new-modular-flake-framework/32395/3)
