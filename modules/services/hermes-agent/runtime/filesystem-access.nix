{
  config,
  lib,
  pkgs,
  ...
}:

let
  nixosConfigRoot = "/etc/nixos";
  crmDatabaseDir = "/home/codyt/.crm";
  obsidianVault = "/home/codyt/Knowledge/Personal";
  projectsRoot = "/home/codyt/Projects";
  inherit (config.services.hermes-agent) group stateDir user;

  managedPaths = [
    crmDatabaseDir
    nixosConfigRoot
    obsidianVault
    projectsRoot
  ];

  sharedRuntimeDirs = [
    "cron"
    "checkpoints"
    "memories"
    "scripts"
    "sessions"
    "skills"
  ];

  servicePrivateFiles = [
    ".env"
    "auth.json"
    "auth.json.corrupt"
    "auth.lock"
  ];

  ensurePathAccess = path: ''
    if [ -d "${path}" ]; then
      ${pkgs.acl}/bin/setfacl -m u:${config.services.hermes-agent.user}:--x /home/codyt
      ${pkgs.acl}/bin/setfacl -R -x u:${config.services.hermes-agent.user} "${path}" 2>/dev/null || true
      find "${path}" -type d -exec ${pkgs.acl}/bin/setfacl -x d:u:${config.services.hermes-agent.user} {} + 2>/dev/null || true

      chgrp users "${path}"
      chmod 2775 "${path}"
      ${pkgs.acl}/bin/setfacl -m g::rwx,d:g::rwx "${path}"

      find "${path}" -type d \( ! -group users -o ! -perm -2000 -o ! -perm -0020 \) -exec chgrp users {} +
      find "${path}" -type d -exec chmod g+rws,u+rwx {} +
      find "${path}" -type d -exec ${pkgs.acl}/bin/setfacl -m g::rwx,d:g::rwx {} +
    fi
  '';
in
{
  config = {
    systemd.services.hermes-agent.serviceConfig.ReadWritePaths = lib.mkAfter managedPaths;

    system.activationScripts.hermes-agent-filesystem-access = lib.stringAfter [ "users" ] (
      lib.concatMapStrings ensurePathAccess managedPaths
    );

    system.activationScripts.hermes-agent-auth-store-access =
      lib.stringAfter [ "hermes-agent-setup" ]
        ''
          hermes_home="${stateDir}/.hermes"
          gws_key="${stateDir}/.config/gws/.encryption_key"

          if [ -d "$hermes_home" ]; then
            chown ${user}:${group} "$hermes_home"
            chmod 2770 "$hermes_home"
          fi

          for private_file in ${lib.concatMapStringsSep " " lib.escapeShellArg servicePrivateFiles}; do
            target="$hermes_home/$private_file"
            if [ -e "$target" ]; then
              chown ${user}:${group} "$target"

              case "$private_file" in
                .env)
                  chmod 0640 "$target"
                  ${pkgs.gnused}/bin/sed -i '/^MESSAGING_CWD=/d' "$target"
                  ;;
                *)
                  chmod 0660 "$target"
                  ;;
              esac
            fi
          done

          if [ -e "$gws_key" ]; then
            chown ${user}:${group} "$gws_key"
            chmod 0600 "$gws_key"
          fi
        '';

    system.activationScripts.hermes-agent-state-access = lib.stringAfter [ "users" ] ''
      hermes_home="${stateDir}/.hermes"
      checkpoints_store="$hermes_home/checkpoints/store"

      mkdir -p "$checkpoints_store"
      chown -R ${user}:${group} "$checkpoints_store"
      chmod -R u+rwX,g+rwX "$checkpoints_store"

      for dir_name in ${lib.concatMapStringsSep " " lib.escapeShellArg sharedRuntimeDirs}; do
        dir_path="$hermes_home/$dir_name"

        mkdir -p "$dir_path"
        chown -R ${user}:${group} "$dir_path"
        chmod 2770 "$dir_path"
        chmod -R u+rwX,g+rwX "$dir_path"
      done

      ${pkgs.findutils}/bin/find "$hermes_home/scripts" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod ug+x {} +
    '';

    users.users.${config.services.hermes-agent.user}.extraGroups = [ "users" ];
  };
}
