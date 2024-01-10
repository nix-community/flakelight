# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config
, options
, src
, lib
, flakelight
, inputs
, outputs
, pkgsFor
, specialArgs
, modulesPath
, moduleArgs
}@args:
{
  _module.args.moduleArgs = args;
}
