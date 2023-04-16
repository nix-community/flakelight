# flakelite -- Framework for making flakes simple
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

{
  inputs.nixpkgs.url = "nixpkgs/nixos-22.11";
  outputs = inputs:
    let
      lib = import ./. inputs;
    in
    lib.mkFlake ./. {
      outputs = { inherit lib; };
    };
}
