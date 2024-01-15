# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, src, lib, flakelight, moduleArgs, ... }:
let
  inherit (lib) mkOption mkIf mkMerge;
  inherit (flakelight) autoImport autoImportArgs;
  inherit (flakelight.types) path;

  autoImport' = autoImport config.nixDir;
  autoImportArgs' = autoImportArgs config.nixDir moduleArgs;
in
{
  options.nixDir = mkOption {
    type = path;
    default = src + /nix;
  };

  config =
    let
      outputs = autoImport' "outputs";
      perSystem = autoImport' "perSystem";
      withOverlays = autoImport' "withOverlays";
      package = autoImport' "package";
      packages = autoImportArgs' "packages";
      overlays = autoImportArgs' "overlays";
      devShell = autoImport' "devShell";
      devShells = autoImportArgs' "devShells";
      app = autoImport' "app";
      apps = autoImport' "apps";
      checks = autoImport' "checks";
      template = autoImportArgs' "template";
      templates = autoImportArgs' "templates";
      formatters = autoImport' "formatters";
      bundler = autoImport' "bundler";
      bundlers = autoImport' "bundlers";
      nixosModule = autoImport' "nixosModule";
      nixosModules = autoImportArgs' "nixosModules";
      nixosConfigurations = autoImportArgs' [ "nixosConfigurations" "nixos" ];
      homeModule = autoImport' "homeModule";
      homeModules = autoImportArgs' "homeModules";
      homeConfigurations = autoImportArgs' [ "homeConfigurations" "home" ];
      flakelightModule = autoImport' "flakelightModule";
      flakelightModules = autoImportArgs' "flakelightModules";
      lib = autoImportArgs' "lib";
      functor = autoImport' "functor";
    in
    mkMerge [
      (mkIf (outputs != null) { inherit outputs; })
      (mkIf (perSystem != null) { inherit perSystem; })
      (mkIf (withOverlays != null) { inherit withOverlays; })
      (mkIf (package != null) { inherit package; })
      (mkIf (packages != null) { inherit packages; })
      (mkIf (overlays != null) { inherit overlays; })
      (mkIf (devShell != null) { inherit devShell; })
      (mkIf (devShells != null) { inherit devShells; })
      (mkIf (app != null) { inherit app; })
      (mkIf (apps != null) { inherit apps; })
      (mkIf (checks != null) { inherit checks; })
      (mkIf (template != null) { inherit template; })
      (mkIf (templates != null) { inherit templates; })
      (mkIf (formatters != null) { inherit formatters; })
      (mkIf (bundler != null) { inherit bundler; })
      (mkIf (bundlers != null) { inherit bundlers; })
      (mkIf (nixosModule != null) { inherit nixosModule; })
      (mkIf (nixosModules != null) { inherit nixosModules; })
      (mkIf (nixosConfigurations != null) { inherit nixosConfigurations; })
      (mkIf (homeModule != null) { inherit homeModule; })
      (mkIf (homeModules != null) { inherit homeModules; })
      (mkIf (homeConfigurations != null) { inherit homeConfigurations; })
      (mkIf (flakelightModule != null) { inherit flakelightModule; })
      (mkIf (flakelightModules != null) { inherit flakelightModules; })
      (mkIf (lib != null) { inherit lib; })
      (mkIf (functor != null) { inherit functor; })
    ];
}
