# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

# This is a fake pkgs set to enable efficiently extracting a derivation's name

real:
let
  inherit (real) lib;

  callPackageWith = autoArgs: fn: args:
    let
      f = if lib.isFunction fn then fn else import fn;
      fargs = lib.functionArgs f;
      mock = lib.mapAttrs (_: _: { }) (lib.filterAttrs (_: v: !v) fargs);
    in
    f (mock // builtins.intersectAttrs fargs autoArgs // args);
in
lib.fix (self: {
  pkgs = self;
  lib = lib // { inherit callPackageWith; };

  callPackage = callPackageWith self;

  stdenv = real.stdenv // {
    mkDerivation = args:
      if lib.isFunction args then lib.fix args else args;
  };

  runCommandWith = args: _: args;
  runCommand = name: _: _: { inherit name; };
  runCommandLocal = name: _: _: { inherit name; };
  runCommandCC = name: _: _: { inherit name; };
  writeTextFile = args: args;
  writeText = name: _: { inherit name; };
  writeTextDir = path: _: { name = builtins.baseNameOf path; };
  writeScript = name: _: { inherit name; };
  writeScriptBin = name: _: { inherit name; };
  writeShellScript = name: _: { inherit name; };
  writeShellScriptBin = name: _: { inherit name; };
  writeShellApplication = args: args;
  writeCBin = pname: _: { inherit pname; };
  concatTextFile = args: args;
  concatText = name: _: { inherit name; };
  concatScript = name: _: { inherit name; };
  symlinkJoin = args: args;
  linkFarm = name: _: { inherit name; };
  linkFarmFromDrvs = name: _: { inherit name; };
})
