{ writeShellApplication
, nix
, git
, gnutar
}:
writeShellApplication {
  name = "pre-commit";
  runtimeInputs = [ nix git gnutar ];
  text = ''
    TREE=$(mktemp -d)
    git archive "$(git write-tree)" | tar -xC "$TREE"
    nix flake check "$TREE"
  '';
}
