# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, src, ... }:
let
  inherit (lib) mkEnableOption mkIf optionalString pathExists;
in
{
  options.flakelite.editorconfig =
    mkEnableOption "editorconfig check" // { default = true; };

  config.checks = mkIf
    (config.flakelite.editorconfig && (pathExists (src + /.editorconfig)))
    {
      # By default, high false-positive flags are disabled.
      editorconfig = { editorconfig-checker, ... }:
        "${editorconfig-checker}/bin/editorconfig-checker"
        + optionalString (!pathExists (src + /.ecrc))
          " -disable-indent-size -disable-max-line-length";
    };
}
