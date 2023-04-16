{ src, lib }:
let
  inherit (lib) getExe optionalAttrs optionalString pathExists;
in
{
  checks = optionalAttrs (pathExists (src + /.editorconfig)) {
    # By default, high false-positive flags are disabled.
    editorconfig = { editorconfig-checker }:
      "${getExe editorconfig-checker}"
      + optionalString (!pathExists (src + /.ecrc))
        " -disable-indent-size -disable-max-line-length";
  };
}
