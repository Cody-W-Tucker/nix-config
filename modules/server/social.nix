{ lib, ... }:
{
  services = {
    mastodon = {
      enable = true;
      localDomain = "social.homehub.tv"; # Replace with your own domain
      configureNginx = true;
      smtp.fromAddress = "noreply@social.homehub.tv"; # Email address used by Mastodon to send emails, replace with your own
      extraConfig = {
        SINGLE_USER_MODE = "true";
        LIMITED_FEDERATION_MODE = "false";
      };
      streamingProcesses = 3; # Number of processes used by the mastodon-streaming service. recommended is the amount of your CPU cores minus one.
    };
    nginx.virtualHosts."social.homehub.tv" = {
      useACMEHost = lib.mkForce "homehub.tv";
      forceSSL = true;
      enableACME = lib.mkForce false; # Ensure enableACME is disabled for this host
    };
  };
}
