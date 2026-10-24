{ stdenv }:

stdenv.mkDerivation {
  pname = "ionix-css";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    $CXX -std=c++23 -O2 -Wall -Wextra -Wpedantic \
      css.cpp manifest.cpp html.cpp optimizer.cpp sha256.cpp io.cpp \
      -o ionix-css

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 ionix-css "$out/bin/ionix-css"

    runHook postInstall
  '';

  meta.description = "CSS optimizer for Ionix";
}
