{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "acpx";
  version = "0.19.4";

  nodejs = nodejs_24; # upstream engines: node >=22.13.0

  src = fetchzip {
    url = "https://registry.npmjs.org/acpx/-/acpx-${version}.tgz";
    hash = "sha256-RTDnP4/XIr8lV6FCM2TmPmckTw3mdL1mg/S8K5vrJ3Y=";
  };

  npmDepsHash = "sha256-G5M4j/SF0+f/Juk+o85qBgXjXtI+6B+NRKuklfmjvMI=";

  # Lock generated from the published tarball (`npm install
  # --package-lock-only` inside the unpacked sources) so the fixed-output npm
  # fetch and the offline `npm ci` stay in sync. Installed with
  # `dontNpmBuild` (dist/ ships prebuilt); the stock install hook prunes
  # devDependencies from the installed node_modules.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true; # dist/ ships prebuilt in the npm tarball

  # `npm pack --dry-run` (used by the install hook to enumerate files) would
  # otherwise run the `prepack` tsdown rebuild; the shipped dist/ is used as-is.
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
