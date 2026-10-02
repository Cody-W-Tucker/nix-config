{ pkgs }:

let
  src = pkgs.linkFarm "research-state-src" [
    {
      name = "main.py";
      path = ./research-state/main.py;
    }
    {
      name = "scope.json";
      path = ./research-state/scope.json;
    }
  ];
in
pkgs.writeShellApplication {
  name = "research-state";
  runtimeInputs = [
    pkgs.python3
    pkgs.git
    pkgs.systemd
  ];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${src}/main.py "$@"
  '';
}
