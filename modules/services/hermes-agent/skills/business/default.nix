{
  inputs,
  pkgs,
  ...
}:

let
  googleWorkspaceCli = inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.gws;
  crmCli = pkgs.callPackage ../../../../../packages/crm-cli { };
in
{
  imports = [
    ./crm
    ./google-workspace
  ];

  services.hermes-agent = {
    extraPackages = [
      googleWorkspaceCli
      crmCli
    ];
  };
}
