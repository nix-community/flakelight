{ writeShellApplication
, coreutils
, nix
, git
, gnutar
}:
writeShellApplication {
  name = "pre-commit";
  runtimeInputs = [ coreutils nix git gnutar ];
  text = ''
    TREE=$(mktemp -d)
    git archive "$(git write-tree)" | tar -xC "$TREE"
    nix flake check "$TREE"
  '';
}
