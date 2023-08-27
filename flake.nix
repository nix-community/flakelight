# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  outputs = inputs:
    let
      flakelight = import ./. inputs;
    in
    flakelight ./. { outputs = flakelight; };
}
