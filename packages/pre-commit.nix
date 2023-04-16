{ writeShellApplication
, nix
, git
, gnutar
}:
writeShellApplication {
  name = "pre-commit";
  runtimeInputs = [ nix git gnutar ];
  text = builtins.readFile ./pre-commit;
}
