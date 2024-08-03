# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{ config, ... }@args:
{
  _module.args.moduleArgs = args // config._module.args;
}
