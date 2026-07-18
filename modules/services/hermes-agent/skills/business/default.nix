{
  inputs,
  pkgs,
  ...
}:

let
  googleWorkspaceCli = inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.gws;
in
{
  imports = [
    ./crm
    ./google-workspace
  ];

  services.hermes-agent = {
    extraPackages = [
      googleWorkspaceCli
    ];
  };
}
