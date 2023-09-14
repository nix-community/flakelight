# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

# A Flakelight module for Flakelight module flakes

{ flakelight, outputs, src, ... }: {
  nixDir = src;
  lib.mkFlake = flakelight.mkFlake.extend [ outputs.flakelightModules.default ];
  functor = self: self.lib.mkFlake;
}
