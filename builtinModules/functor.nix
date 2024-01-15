# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, lib, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types) functionTo nullOr raw uniq;
in
{
  options.functor = mkOption {
    type = nullOr (uniq (functionTo (functionTo raw)));
    default = null;
  };

  config.outputs = mkIf (config.functor != null) (_: {
    __functor = config.functor;
  });
}
