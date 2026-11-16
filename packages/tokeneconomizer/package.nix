{
  lib,
  fetchFromGitHub,
  python3,
  runCommand,
}:

let
  rev = "7042ea89dd5e5ecbc67ad865ad6e256e61be8bf0";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "TokenEconomizer";
    inherit rev;
    hash = "sha256-IuEqn7pOs/WmoBBrD3pKl40vlCHkfmY5eTy8X+nWSoc=";
  };

  pythonBin = lib.getExe python3;
in
runCommand "tokeneconomizer-0.1.0-unstable-2026-11-15"
  {
    inherit src;
    passthru = {
      inherit python3 rev src;
    };
    meta = {
      description = "Experience-driven black-box cost control for coding agents";
      homepage = "https://github.com/microsoft/TokenEconomizer";
      license = lib.licenses.asl20;
      mainProgram = "te";
    };
  }
  ''
    cp -R "${src}" repo
    chmod -R u+w repo
    ${pythonBin} repo/scripts/build_plugin.py --out "$out"

    substituteInPlace "$out/tokeneconomizer/scripts/te" "$out/tokeneconomizer/scripts/te-hook" \
      --replace-fail 'for py in "''${TE_PYTHON:-}" python3 python;' \
                     'for py in "''${TE_PYTHON:-}" ${pythonBin} python3 python;'

    patchShebangs "$out/tokeneconomizer/scripts"
    mkdir -p "$out/bin"
    cat > "$out/bin/te" <<EOF
    #!/bin/sh
    exec "$out/tokeneconomizer/scripts/te" "\$@"
    EOF
    chmod +x "$out/bin/te"
    patchShebangs "$out/bin"
  ''
