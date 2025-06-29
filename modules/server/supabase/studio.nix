{ config, lib, ... }:

{
  # Secrets
  sops.secrets = {
    SUPABASE_JWT_SECRET = { };
    OPENAI_API_KEY = { };
    SUPABASE_POSTGRES_PASSWORD = { };
    SUPABASE_ANON_KEY = { };
    SUPABASE_SERVICE_ROLE_KEY = { };
  };

  sops.templates = {
    "studio".content = ''
      AUTH_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
      OPENAI_API_KEY=${config.sops.placeholder."OPENAI_API_KEY"}
      POSTGRES_PASSWORD=${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}
      SUPABASE_ANON_KEY=${config.sops.placeholder."SUPABASE_ANON_KEY"}
      SUPABASE_SERVICE_KEY=${config.sops.placeholder."SUPABASE_SERVICE_ROLE_KEY"}
    '';
  };

  # Studio dashboard
  virtualisation.oci-containers.containers."supabase-studio" = {
    image = "supabase/studio:2025.06.02-sha-8f2993d";
    environmentFiles = [
      config.sops.templates."studio".path
    ];
    environment = {
      "DEFAULT_ORGANIZATION_NAME" = "TMV Social";
      "DEFAULT_PROJECT_NAME" = "Business Backend";
      "NEXT_ANALYTICS_BACKEND_PROVIDER" = "postgres";
      "NEXT_PUBLIC_ENABLE_LOGS" = "false";
      "STUDIO_PG_META_URL" = "http://meta:8080";
      "SUPABASE_PUBLIC_URL" = "https://studio.homehub.tv";
      "SUPABASE_URL" = "http://kong:8000";
    };
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=node -e \"require('http').get('http://' + require('os').hostname() + ':3000/api/platform/profile', r => process.exit(r.statusCode === 200 ? 0 : 1))\""
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=10s"
      "--network-alias=studio"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-studio" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
}
