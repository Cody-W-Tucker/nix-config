{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.codyos.hermes-agent.locations) obsidianVault projectsRoot;

  managedPaths = [
    obsidianVault
    projectsRoot
  ];

  ensurePathAccess = path: ''
    if [ -d "${path}" ]; then
      ${pkgs.acl}/bin/setfacl -m u:${config.services.hermes-agent.user}:--x /home/codyt
      ${pkgs.acl}/bin/setfacl -R -x u:${config.services.hermes-agent.user} "${path}" 2>/dev/null || true
      find "${path}" -type d -exec ${pkgs.acl}/bin/setfacl -x d:u:${config.services.hermes-agent.user} {} + 2>/dev/null || true

      chgrp -hR users "${path}"
      ${pkgs.acl}/bin/setfacl -R -m g::rwX "${path}"
      find "${path}" -type d -exec ${pkgs.acl}/bin/setfacl -m d:g::rwx {} +
      chmod -R u+rwX,g+rwX "${path}"
      find "${path}" -type d -exec chmod g+s {} +
    fi
  '';
in
{
  options.codyos.hermes-agent.locations = {
    obsidianVault = lib.mkOption {
      type = lib.types.str;
      default = "/home/codyt/Knowledge/Personal";
      description = "Obsidian vault path exposed to Hermes.";
    };

    projectsRoot = lib.mkOption {
      type = lib.types.str;
      default = "/home/codyt/Projects";
      description = "Projects root path Hermes can access.";
    };

    projectWorkspace = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/work/dev/hermes";
      description = "Default Hermes working directory.";
    };
  };

  config = {
    system.activationScripts.hermes-agent-filesystem-access = lib.stringAfter [ "users" ] (
      lib.concatMapStrings ensurePathAccess managedPaths
    );

    users.users.${config.services.hermes-agent.user}.extraGroups = [ "users" ];
  };
}
