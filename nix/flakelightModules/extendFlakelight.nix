# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

# A Flakelight module for Flakelight module flakes

{ flakelight, outputs, ... }: {
  # Export a mkFlake function equivalent to flakelight's but with the flake's
  # default flakelightModule built in.
  lib.mkFlake = flakelight.mkFlake.extend [ outputs.flakelightModules.default ];
  # Make the flake callable, which executes its mkFlake.
  functor = self: self.lib.mkFlake;
}
