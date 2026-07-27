{
  config,
  pkgs,
  inputs,
  ...
}:

let
  passwordFile = config.sops.secrets."opencode-password".path;
  opencodeServe = pkgs.writeShellScript "opencode-serve" ''
    export OPENCODE_SERVER_PASSWORD="$(cat ${passwordFile})"
    export HOME="/home/codyt"
    exec ${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port 4096
  '';
in
{
  # Pull opencode from nixpkgs-unstable so the NAS service tracks the same
  # version Beast ships, without making the rest of NAS unstable.
  nixpkgs.overlays = [
    (final: prev: {
      opencode = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.opencode;
    })
  ];

  sops.secrets."opencode-password" = {
    owner = "codyt";
  };

  systemd.services.opencode = {
    description = "OpenCode Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = "codyt";
      ExecStart = opencodeServe;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  services.nginx.virtualHosts."opencode.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:4096";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
