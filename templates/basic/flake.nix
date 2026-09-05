{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    flakelight.url = "github:nix-community/flakelight";
  };
  outputs = { flakelight, ... }@inputs:
    flakelight ./. {
      inherit inputs;
      devShell.packages = pkgs: with pkgs; [ hello ];
    };
}
