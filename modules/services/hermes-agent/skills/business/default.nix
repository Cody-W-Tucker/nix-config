{
  config,
  inputs,
  pkgs,
  ...
}:

let
  crmCli = inputs.crm-cli.packages.${pkgs.stdenv.hostPlatform.system}.crm-cli;
  googleWorkspaceCli = inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.gws;
in
{
  imports = [
    ./crm
    ./google-workspace
  ];

  services.hermes-agent = {
    extraPackages = [
      crmCli
      googleWorkspaceCli
    ];
  };
}
