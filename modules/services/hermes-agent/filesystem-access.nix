{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.codyos.hermes-agent.locations) nixosConfigRoot obsidianVault projectsRoot;
  inherit (config.services.hermes-agent) group stateDir user;
  gbrainRoot = "/home/codyt/Knowledge/GBrain";
  managedPaths = [
    nixosConfigRoot
    obsidianVault
    projectsRoot
    gbrainRoot
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
    mkdir -p "${path}"
    ${pkgs.acl}/bin/setfacl -m u:${config.services.hermes-agent.user}:--x /home/codyt
    ${pkgs.acl}/bin/setfacl -R -x u:${config.services.hermes-agent.user} "${path}" 2>/dev/null || true
    find "${path}" -type d -exec ${pkgs.acl}/bin/setfacl -x d:u:${config.services.hermes-agent.user} {} + 2>/dev/null || true

    chgrp -hR users "${path}"
    ${pkgs.acl}/bin/setfacl -R -m g::rwX "${path}"
    find "${path}" -type d -exec ${pkgs.acl}/bin/setfacl -m d:g::rwx {} +
    chmod -R u+rwX,g+rwX "${path}"
    find "${path}" -type d -exec chmod g+s {} +
  '';
in
{
  options.codyos.hermes-agent.locations = {
    obsidianVault = lib.mkOption {
      type = lib.types.str;
      default = "/home/codyt/Knowledge/Personal";
      description = "Obsidian vault path exposed to Hermes.";
    };

    nixosConfigRoot = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "NixOS config repo path exposed to Hermes.";
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

    systemd.services.hermes-agent.serviceConfig.ReadWritePaths = lib.mkAfter managedPaths;

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
                  # The unit now sets terminal.cwd declaratively; drop stale legacy env.
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

    # Hermes keeps checkpoints in a git repo under its state dir. Ensure the
    # service user always owns that repo so git gc can create lock files.
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

      # Hermes cron script hooks execute files directly, so common script
      # types need explicit execute bits even when they were created from a
      # non-executable editor or tool.
      ${pkgs.findutils}/bin/find "$hermes_home/scripts" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod ug+x {} +
    '';

    users.users.${config.services.hermes-agent.user}.extraGroups = [ "users" ];
  };
}
