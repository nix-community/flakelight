_: {
  devTools = pkgs: with pkgs; [ nixpkgs-fmt nodePackages.prettier ];
  formatters = {
    "*.nix" = "nixpkgs-fmt";
    "*.md | *.json | *.yml" = "prettier --write";
  };
}
