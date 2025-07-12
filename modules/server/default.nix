{ config, pkgs, ... }:

{
  imports = [
    ./actualBudget.nix
    ./arm.nix
    ./adguard.nix
    ./automation.nix
    ./content.nix
    ./data.nix
    ./excalidraw.nix
    ./hoarder.nix
    ./homepage-dashboard.nix
    ./media.nix
    ./monitoring.nix
    # ./nextcloud.nix
    ./paperless.nix
    ./stirling-pdf.nix
    ./photos.nix
    ./samba.nix
    ./syncthing.nix
    ./security.nix
    ./penpot.nix
    ./supabase/default.nix
  ];

  # Create the acme secret in sops
  sops.secrets.cloudflare-api-email = { };
  sops.secrets.cloudflare-api-key = { };

  # Acme for SSL
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "cody@tmvsocial.com";
    };
    certs."homehub.tv" = {
      domain = "homehub.tv";
      extraDomainNames = [ "*.homehub.tv" ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      credentialFiles = {
        "CF_API_EMAIL_FILE" = config.sops.secrets.cloudflare-api-email.path;
        "CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-api-key.path;
      };
    };
  };

  services.nginx = {
    enable = true;
    package = pkgs.nginxMainline;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    appendHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';
    virtualHosts = {
      "qdrant.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        # HTTP API (REST API on port 6333)
        locations."/" = {
          proxyPass = "http://192.168.1.20:6333"; # Forward REST traffic
          proxyWebsockets = true; # Extra flexibility for WebSockets (not required for REST API)
          # Optional: Add headers to preserve proxy context
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          '';
        };
        # gRPC API (on port 6334)
        locations."/grpc" = {
          proxyPass = "http://192.168.1.20:6334"; # Forward gRPC traffic
          extraConfig = ''
            grpc_set_header Host $host;
            grpc_set_header X-Real-IP $remote_addr;
            grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            grpc_pass grpc://192.168.1.20:6334;    # Ensure grpc_pass for gRPC-specific handling
          '';
        };
      };
      "ai.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        kTLS = true;
        locations."/" = {
          proxyPass = "http://192.168.1.20:8080";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            client_max_body_size 256m;
          '';
        };
      };
      "tika.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        kTLS = true;
        locations."/" = {
          proxyPass = "http://192.168.1.20:9998";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Tika-OCRLanguage "chi_sim+eng";
          '';
        };
      };
      "ollama.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        kTLS = true;
        locations."/" = {
          proxyPass = "http://192.168.1.20:11434";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            add_header Access-Control-Allow-Origin '*' always;
            add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
            add_header Access-Control-Allow-Headers 'Content-Type, Authorization' always;

            if ($request_method = 'OPTIONS') {
              add_header Access-Control-Max-Age 1728000;
              return 204;
            }
          '';
        };
      };
    };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 80 443 6333 6334 ];
  };

  # Using Docker
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    oci-containers.backend = "docker";
  };
}
