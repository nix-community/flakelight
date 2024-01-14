{ self, nixpkgs, ... }:
let
  flakelight = self;
  test = flake: test: assert test flake; true;
  inherit (nixpkgs) lib;
in
{
  call-flakelight = test
    (flakelight ./empty { outputs.test = true; })
    (f: f.test);

  explicit-mkFlake = test
    (flakelight.lib.mkFlake ./empty { outputs.test = true; })
    (f: f.test);

  module-with-args = test
    (flakelight ./empty ({ lib, config, ... }: { outputs.test = true; }))
    (f: f.test);

  src-arg = test
    (flakelight ./test-path ({ src, ... }: {
      outputs = { inherit src; };
    }))
    (f: f.src == ./test-path);

  lib-arg = test
    (flakelight ./empty ({ lib, ... }: {
      outputs = { inherit lib; };
    }))
    (f: f.lib ? fix);

  config-arg = test
    (flakelight ./empty ({ config, ... }: {
      lib = { a = true; };
      outputs = { inherit config; };
    }))
    (f: f.config.lib.a);

  options-arg = test
    (flakelight ./empty ({ options, ... }: {
      outputs = { inherit options; };
    }))
    (f: f.options ? package && f.options ? overlays);

  flakelight-arg = test
    (flakelight ./empty ({ flakelight, ... }: {
      outputs = { inherit flakelight; };
    }))
    (f: f.flakelight ? mkFlake);

  inputs-arg = test
    (flakelight ./empty ({ inputs, ... }: {
      inputs.test = true;
      outputs = { inherit inputs; };
    }))
    (f: f.inputs.test);

  overridden-nixpkgs = test
    (flakelight ./empty ({ inputs, ... }: {
      inputs.nixpkgs = nixpkgs // { testValue = true; };
      outputs = { inherit inputs; };
    }))
    (f: f.inputs.nixpkgs.testValue);

  outputs-arg = test
    (flakelight ./empty ({ outputs, ... }: {
      lib.test = true;
      outputs.test = outputs.lib.test;
    }))
    (f: f.test);

  outputs-moduleArgs = test
    (flakelight ./empty ({ moduleArgs, ... }: {
      outputs = { inherit moduleArgs; };
    }))
    (f: f.moduleArgs ? lib
      && f.moduleArgs ? src
      && f.moduleArgs ? inputs
      && f.moduleArgs ? outputs
      && f.moduleArgs ? flakelight);

  extra-pkgs-vals = test
    (flakelight ./empty {
      package =
        { src
        , inputs
        , outputs
        , flakelight
        , inputs'
        , outputs'
        , defaultMeta
        , writeText
        }:
        writeText "test" "";
    })
    (f: f.packages.x86_64-linux.default.name == "test");

  inputs' = test
    (flakelight ./empty {
      systems = [ "x86_64-linux" ];
      inputs.a.attr.x86_64-linux = true;
      perSystem = { inputs', ... }: { test = inputs'.a.attr && true; };
    })
    (f: f.test.x86_64-linux);

  outputs' = test
    (flakelight ./empty {
      systems = [ "x86_64-linux" ];
      outputs.attr.x86_64-linux = true;
      perSystem = { outputs', ... }: { test = outputs'.attr && true; };
    })
    (f: f.test.x86_64-linux);

  systems = test
    (flakelight ./empty {
      systems = [ "i686-linux" "armv7l-linux" ];
      perSystem = _: { test = true; };
    })
    (f: (builtins.attrNames f.test) == [ "armv7l-linux" "i686-linux" ]);

  all-flakes-systems = test
    (flakelight ./empty ({ lib, ... }: {
      systems = lib.systems.flakeExposed;
      perSystem = _: { test = true; };
    }))
    (f: builtins.deepSeq f.test f.test.x86_64-linux);

  all-linux-systems = test
    (flakelight ./empty ({ lib, ... }: {
      systems = lib.intersectLists
        lib.systems.doubles.linux
        lib.systems.flakeExposed;
      perSystem = _: { test = true; };
    }))
    (f: builtins.deepSeq f.test f.test.x86_64-linux);

  outputs = test
    (flakelight ./empty {
      outputs.example.test = true;
    })
    (f: f.example.test);

  outputs-handled-attr = test
    (flakelight ./empty {
      outputs.overlays.test = final: prev: { testVal = true; };
    })
    (f: (nixpkgs.legacyPackages.x86_64-linux.extend f.overlays.test).testVal);

  perSystem = test
    (flakelight ./empty {
      perSystem = _: { test = true; };
    })
    (f: (builtins.attrNames f.test) == [ "aarch64-linux" "x86_64-linux" ]);

  withOverlays = test
    (flakelight ./empty {
      withOverlays = final: prev: { testValue = "true"; };
      package = { writeText, testValue }: writeText "test" "${testValue}";
    })
    (f: import f.packages.x86_64-linux.default);

  withOverlays-multiple = test
    (flakelight ./empty {
      withOverlays = [
        (final: prev: { testValue = "tr"; })
        (final: prev: { testValue2 = "ue"; })
      ];
      package = { writeText, testValue, testValue2 }:
        writeText "test" "${testValue}${testValue2}";
    })
    (f: import f.packages.x86_64-linux.default);

  package = test
    (flakelight ./empty {
      package = { stdenv }:
        stdenv.mkDerivation {
          pname = "pkg1";
          version = "0.0.1";
          src = ./empty;
          installPhase = "echo true > $out";
        };
    })
    (f: (import f.packages.x86_64-linux.default)
      && (f ? packages.aarch64-linux.default)
      && ((nixpkgs.legacyPackages.x86_64-linux.extend f.overlays.default) ? pkg1)
      && (f ? checks.x86_64-linux.packages-default)
      && (f ? checks.aarch64-linux.packages-default));

  packages = test
    (flakelight ./empty {
      packages = {
        default = { stdenv }:
          stdenv.mkDerivation {
            name = "pkg1";
            src = ./empty;
            installPhase = "echo true > $out";
          };
        pkg2 = { stdenv, pkg1, pkg3 }:
          stdenv.mkDerivation {
            name = "hello-world";
            src = ./empty;
            nativeBuildInputs = [ pkg1 pkg3 ];
            installPhase = "echo true > $out";
          };
        pkg3 = { stdenv }:
          stdenv.mkDerivation {
            name = "hello-world";
            src = ./empty;
            installPhase = "echo true > $out";
          };
      };
    })
    (f:
      (import f.packages.x86_64-linux.default)
      && (import f.packages.x86_64-linux.pkg2)
      && (import f.packages.x86_64-linux.pkg3)
      && (
        let
          pkgs' = nixpkgs.legacyPackages.x86_64-linux.extend f.overlays.default;
        in
        (pkgs' ? pkg1) && (pkgs' ? pkg2) && (pkgs' ? pkg3)
      )
      && (f ? checks.x86_64-linux.packages-default)
      && (f ? checks.x86_64-linux.packages-pkg2)
      && (f ? checks.x86_64-linux.packages-pkg3)
    );

  package-overlay-no-default = test
    (flakelight ./empty {
      package = { stdenv }:
        stdenv.mkDerivation {
          name = "pkg1";
          src = ./empty;
          installPhase = "echo true > $out";
        };
    })
    (f: !((nixpkgs.legacyPackages.x86_64-linux.extend f.overlays.default)
      ? default));

  packages-refer-default-as-default = test
    (flakelight ./empty {
      packages = {
        default = { stdenv }:
          stdenv.mkDerivation {
            name = "pkg1";
            src = ./empty;
            installPhase = "echo true > $out";
          };
        pkg2 = { stdenv, default }:
          stdenv.mkDerivation {
            name = "hello-world";
            src = ./empty;
            installPhase = "cat ${default} > $out";
          };
      };
    })
    (f: (import f.packages.x86_64-linux.pkg2));

  packages-refer-default-as-name = test
    (flakelight ./empty {
      packages = {
        default = { stdenv }:
          stdenv.mkDerivation {
            name = "pkg1";
            src = ./empty;
            installPhase = "echo true > $out";
          };
        pkg2 = { stdenv, pkg1 }:
          stdenv.mkDerivation {
            name = "hello-world";
            src = ./empty;
            installPhase = "cat ${pkg1} > $out";
          };
      };
    })
    (f: (import f.packages.x86_64-linux.pkg2));

  devShell = test
    (flakelight ./empty {
      devShell = {
        inputsFrom = pkgs: [ pkgs.emacs ];
        packages = pkgs: [ pkgs.coreutils ];
        shellHook = ''
          echo Welcome to example shell!
        '';
        env.TEST_VAR = "test value";
        stdenv = pkgs: pkgs.clangStdenv;
      };
    })
    (f: lib.isDerivation f.devShells.x86_64-linux.default);

  devShell-empty = test
    (flakelight ./empty {
      disabledModules = [ "builtinFormatters.nix" ];
      devShell = { };
    })
    (f: lib.isDerivation f.devShells.x86_64-linux.default);

  devShell-override = test
    (flakelight ./empty {
      devShell = { mkShell }: mkShell { };
    })
    (f: lib.isDerivation f.devShells.x86_64-linux.default);

  devShell-override-empty = test
    (flakelight ./empty {
      disabledModules = [ "builtinFormatters.nix" ];
      devShell = { mkShell }: mkShell { };
    })
    (f: lib.isDerivation f.devShells.x86_64-linux.default);

  devShells = test
    (flakelight ./empty {
      devShell.inputsFrom = pkgs: [ pkgs.emacs ];
      devShells = {
        shell1 = { mkShell }: mkShell { };
        shell2 = { mkShell }: mkShell { };
      };
    })
    (f: (f ? devShells.x86_64-linux.default)
      && (f ? devShells.x86_64-linux.shell1)
      && (f ? devShells.x86_64-linux.shell2));

  devShells-override = test
    (flakelight ./empty {
      devShells.default = { mkShell }: mkShell { };
    })
    (f: f ? devShells.x86_64-linux.default);

  overlay = test
    (flakelight ./empty {
      overlay = final: prev: { testValue = "hello"; };
    })
    (f:
      (lib.fix (self: f.overlays.default self { })) ==
      { testValue = "hello"; }
    );

  overlays = test
    (flakelight ./empty {
      overlay = final: prev: { testValue = "hello"; };
      overlays.cool = final: prev: { testValue = "cool"; };
    })
    (f:
      ((lib.fix (self: f.overlays.default self { })) ==
      { testValue = "hello"; })
      && ((lib.fix (self: f.overlays.cool self { })) ==
      { testValue = "cool"; }));

  overlay-merge = test
    (flakelight ./empty {
      imports = [
        { overlay = final: prev: { testValue = "hello"; }; }
        { overlay = final: prev: { testValue2 = "hello2"; }; }
      ];
    })
    (f: ((lib.fix (self: f.overlays.default self { })) ==
      { testValue = "hello"; testValue2 = "hello2"; }));

  overlays-merge = test
    (flakelight ./empty {
      imports = [
        { overlays.test = final: prev: { testValue = "hello"; }; }
        { overlays.test = final: prev: { testValue2 = "hello2"; }; }
      ];
    })
    (f: ((lib.fix (self: f.overlays.test self { })) ==
      { testValue = "hello"; testValue2 = "hello2"; }));

  checks = test
    (flakelight ./empty {
      checks = {
        test-fail = pkgs: "exit 1";
        test-success = pkgs: pkgs.hello;
      };
    })
    (f: (f ? checks.x86_64-linux.test-fail)
      && (lib.isDerivation f.checks.x86_64-linux.test-success)
      && (f ? checks.x86_64-linux.test-success)
      && (lib.isDerivation f.checks.x86_64-linux.test-success));

  app = test
    (flakelight ./empty {
      app = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello";
      };
    })
    (f: (f.apps.x86_64-linux.default == {
      type = "app";
      program = "${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello";
    }));

  app-fn = test
    (flakelight ./empty {
      app = pkgs: {
        type = "app";
        program = "${pkgs.hello}/bin/hello";
      };
    })
    (f: (f.apps.x86_64-linux.default == {
      type = "app";
      program = "${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello";
    }));

  app-string = test
    (flakelight ./empty {
      inputs = { inherit nixpkgs; };
      app = "/bin/sh";
    })
    (f: (f.apps.x86_64-linux.default == {
      type = "app";
      program = "/bin/sh";
    }));

  app-string-fn = test
    (flakelight ./empty {
      inputs = { inherit nixpkgs; };
      app = pkgs: "${pkgs.hello}/bin/hello";
    })
    (f: (f.apps.x86_64-linux.default == {
      type = "app";
      program = "${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello";
    }));

  apps = test
    (flakelight ./empty {
      inputs = { inherit nixpkgs; };
      apps = {
        shell = "/bin/sh";
        emacs = pkgs: "${pkgs.emacs}/bin/emacs";
        bash = pkgs: { type = "app"; program = "${pkgs.bash}/bin/bash"; };
      };
    })
    (f: f.apps.x86_64-linux == {
      shell = {
        type = "app";
        program = "/bin/sh";
      };
      emacs = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.emacs}/bin/emacs";
      };
      bash = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.bash}/bin/bash";
      };
    });

  apps-fn = test
    (flakelight ./empty {
      inputs = { inherit nixpkgs; };
      apps = { emacs, bash, ... }: {
        emacs = "${emacs}/bin/emacs";
        bash = { type = "app"; program = "${bash}/bin/bash"; };
      };
    })
    (f: f.apps.x86_64-linux == {
      emacs = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.emacs}/bin/emacs";
      };
      bash = {
        type = "app";
        program = "${nixpkgs.legacyPackages.x86_64-linux.bash}/bin/bash";
      };
    });

  template = test
    (flakelight ./empty {
      template = {
        path = ./test;
        description = "test template";
      };
    })
    (f: f.templates.default == {
      path = ./test;
      description = "test template";
    });

  templates = test
    (flakelight ./empty {
      templates.test-template = {
        path = ./test;
        description = "test template";
      };
    })
    (f: f.templates.test-template == {
      path = ./test;
      description = "test template";
    });

  templates-welcomeText = test
    (flakelight ./empty {
      templates.test-template = {
        path = ./test;
        description = "test template";
        welcomeText = "hi";
      };
    })
    (f: f.templates.test-template == {
      path = ./test;
      description = "test template";
      welcomeText = "hi";
    });

  formatter = test
    (flakelight ./empty {
      formatter = pkgs: pkgs.hello;
    })
    (f: lib.isDerivation f.formatter.x86_64-linux);

  formatters = test
    (flakelight ./empty {
      devShell.packages = pkgs: [ pkgs.rustfmt ];
      formatters = {
        "*.rs" = "rustfmt";
      };
    })
    (f: lib.isDerivation f.formatter.x86_64-linux);

  formatters-fn = test
    (flakelight ./empty {
      formatters = { rustfmt, ... }: {
        "*.rs" = "${rustfmt}";
      };
    })
    (f: lib.isDerivation f.formatter.x86_64-linux);

  formatters-no-devshell = test
    (flakelight ./empty {
      devShell = lib.mkForce null;
      formatters = { rustfmt, ... }: {
        "*.rs" = "${rustfmt}";
      };
    })
    (f: lib.isDerivation f.formatter.x86_64-linux);

  formatters-disable = test
    (flakelight ./empty {
      flakelight.builtinFormatters = false;
    })
    (f: ! f ? formatter.x86_64-linux);

  formatters-disable-only-builtin = test
    (flakelight ./empty {
      flakelight.builtinFormatters = false;
      formatters = { rustfmt, ... }: {
        "*.rs" = "rustfmt";
      };
    })
    (f: f ? formatter.x86_64-linux);

  bundler = test
    (flakelight ./empty {
      bundler = x: x;
    })
    (f: (f.bundlers.x86_64-linux.default
      nixpkgs.legacyPackages.x86_64-linux.hello)
    == nixpkgs.legacyPackages.x86_64-linux.hello);

  bundler-fn = test
    (flakelight ./empty {
      bundler = pkgs: x: pkgs.hello;
    })
    (f: (f.bundlers.x86_64-linux.default
      nixpkgs.legacyPackages.x86_64-linux.emacs)
    == nixpkgs.legacyPackages.x86_64-linux.hello);

  bundlers = test
    (flakelight ./empty {
      bundlers = {
        hello = x: x;
      };
    })
    (f: (f.bundlers.x86_64-linux.hello
      nixpkgs.legacyPackages.x86_64-linux.hello)
    == nixpkgs.legacyPackages.x86_64-linux.hello);

  bundlers-fn = test
    (flakelight ./empty {
      bundlers = { hello, ... }: {
        hello = x: hello;
      };
    })
    (f: (f.bundlers.x86_64-linux.hello
      nixpkgs.legacyPackages.x86_64-linux.emacs)
    == nixpkgs.legacyPackages.x86_64-linux.hello);

  nixosConfigurations = test
    (flakelight ./empty ({ lib, ... }: {
      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ];
      };
    }))
    (f: f ? nixosConfigurations.test.config.system.build.toplevel);

  nixosConfigurationsWithProp = test
    (flakelight ./empty ({ lib, config, ... }: {
      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          config.propagationModule
          ({ flake, ... }: {
            system.stateVersion = "24.05";
            environment.variables = {
              TEST1 = flake.inputs.nixpkgs.legacyPackages.x86_64-linux.hello;
              TEST2 = flake.inputs'.nixpkgs.legacyPackages.hello;
            };
          })
        ];
      };
    }))
    (f: (f ? nixosConfigurations.test.config.system.build.toplevel)
      && (f.nixosConfigurations.test.config.environment.variables.TEST1 ==
      f.nixosConfigurations.test.config.environment.variables.TEST2));

  nixosModule = test
    (flakelight ./empty {
      nixosModule = _: { };
    })
    (f: f ? nixosModules.default);

  nixosModules = test
    (flakelight ./empty {
      nixosModules.test = _: { };
    })
    (f: f ? nixosModules.test);

  homeModule = test
    (flakelight ./empty {
      homeModule = _: { };
    })
    (f: f ? homeModules.default);

  homeModules = test
    (flakelight ./empty {
      homeModules.test = _: { };
    })
    (f: f ? homeModules.test);

  flakelightModule = test
    (flakelight ./empty {
      flakelightModule = _: { };
    })
    (f: f ? flakelightModules.default);

  flakelightModules = test
    (flakelight ./empty {
      flakelightModules.test = _: { };
    })
    (f: f ? flakelightModules.test);

  lib = test
    (flakelight ./empty {
      lib.addFive = x: x + 5;
    })
    (f: f.lib.addFive 4 == 9);

  functor = test
    (flakelight ./empty {
      outputs.testvalue = 5;
      functor = self: x: x + self.testvalue;
    })
    (f: f 4 == 9);

  meta = test
    (flakelight ./empty {
      description = "aaa";
      license = "AGPL-3.0-only";
      packages.test = { writeTextFile, defaultMeta }:
        writeTextFile {
          name = "test";
          text = "";
          meta = defaultMeta;
        };
    })
    (f: (f.packages.x86_64-linux.test.meta.description == "aaa")
      && (f.packages.x86_64-linux.test.meta.license.spdxId
      == "AGPL-3.0-only"));

  meta-license-attrname = test
    (flakelight ./empty {
      license = "agpl3Only";
      packages.test = { writeTextFile, defaultMeta }:
        writeTextFile {
          name = "test";
          text = "";
          meta = defaultMeta;
        };
    })
    (f: f.packages.x86_64-linux.test.meta.license.spdxId == "AGPL-3.0-only");

  meta-licenses = test
    (flakelight ./empty {
      license = [ "agpl3Only" "AGPL-3.0-or-later" ];
      packages.test = { writeTextFile, defaultMeta }:
        writeTextFile {
          name = "test";
          text = "";
          meta = defaultMeta;
        };
    })
    (f: builtins.isList f.packages.x86_64-linux.test.meta.license);

  editorconfig = test
    (flakelight ./editorconfig { })
    (f: f ? checks.x86_64-linux.editorconfig);

  editorconfig-disabled = test
    (flakelight ./editorconfig {
      flakelight.editorconfig = false;
    })
    (f: ! f ? checks.x86_64-linux.editorconfig);

  modulesPath = test
    (flakelight ./empty {
      disabledModules = [ "functor.nix" "nixDir.nix" ];
      functor = _: _: true;
    })
    (f: !(builtins.tryEval f).success);

  empty-flake = test
    (flakelight ./empty {
      disabledModules = [ "builtinFormatters.nix" ];
    })
    (f: f == { });

  default-nixpkgs = test
    (flakelight ./empty ({ inputs, ... }: {
      outputs = { inherit inputs; };
    }))
    (f: f.inputs ? nixpkgs.lib);

  extend-mkFlake =
    let
      extended = flakelight.lib.mkFlake.extend [{ outputs.test = true; }];
    in
    test
      (extended ./empty { })
      (f: f.test);

  extend-mkFlake-nested =
    let
      extended = flakelight.lib.mkFlake.extend [{ outputs.test = true; }];
      extended2 = extended.extend [{ outputs.test2 = true; }];
      extended3 = extended2.extend [{ outputs.test3 = true; }];
    in
    test
      (extended3 ./empty { })
      (f: f.test && f.test2 && f.test3);
}
