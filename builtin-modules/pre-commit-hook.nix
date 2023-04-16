_: {
  shellHook = { lib, flakelite }: ''
    if [ -f flake.nix ] && [ -d .git/hooks ] &&
       [ ! -f .git/hooks/pre-commit ]; then
      echo Installing git pre-commit hook...
      cp ${lib.getExe flakelite.inputs'.flakelite.packages.pre-commit-hook
          } .git/hooks
    fi
  '';
}
