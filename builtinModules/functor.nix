# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, flakelight, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) functionTo raw uniq;
  inherit (flakelight.types) nullable;
in
{
  options.functor = mkOption {
    type = nullable (uniq (functionTo (functionTo raw)));
    default = null;
  };

  config.outputs = mkIf (config.functor != null) (_: {
    __functor = config.functor;
  });
}
