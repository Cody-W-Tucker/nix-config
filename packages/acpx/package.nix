{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "acpx";
  version = "0.19.4";

  nodejs = nodejs_24;

  src = fetchzip {
    url = "https://registry.npmjs.org/acpx/-/acpx-${version}.tgz";
    hash = "sha256-RTDnP4/XIr8lV6FCM2TmPmckTw3mdL1mg/S8K5vrJ3Y=";
  };

  npmDepsHash = "sha256-G5M4j/SF0+f/Juk+o85qBgXjXtI+6B+NRKuklfmjvMI=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  npmPackFlags = [ "--ignore-scripts" ];

  meta = {
    description = "Headless CLI client for the Agent Client Protocol (ACP) - talk to coding agents from the command line";
    homepage = "https://github.com/openclaw/acpx";
    downloadPage = "https://www.npmjs.com/package/acpx";
    license = lib.licenses.mit;
    mainProgram = "acpx";
    platforms = [ "x86_64-linux" ];
  };
}
