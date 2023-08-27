{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flakelight.url = "github:accelbread/flakelight";
  };
  outputs = { flakelight, ... }@inputs:
    flakelight ./. {
      inherit inputs;
      devShell.packages = pkgs: with pkgs; [ hello ];
    };
}
