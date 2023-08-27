# flakelight -- Framework for simplifying flake setup
# Copyright (C) 2023 Archit Gupta <archit@accelbread.com>
# SPDX-License-Identifier: MIT

rec {
  default = basic;
  basic = { path = ./basic; description = "Minimal Flakelight flake."; };
}
