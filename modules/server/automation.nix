{ config, ... }:

{
  # n8n is a workflow automation tool that allows you to automate tasks.
  services.n8n = {
    enable = true;
    openFirewall = true;
  };
}
