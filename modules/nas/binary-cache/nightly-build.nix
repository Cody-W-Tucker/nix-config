# Nightly: build every host from GitHub `main` (filling the Harmonia cache),
# then switch the NAS to it, but only if the NAS's /etc/nixos checkout has no
# uncommitted or unpushed work. Also pre-builds the pending flake-update PR
# branch, so merging it is already a cache hit.
#
# Builds are GC-rooted under /nix/var/nix/gcroots/nightly-build so the weekly
# GC keeps beast's closure on the NAS.
{
  config,
  pkgs,
  ...
}:

let
  nightlyBuild = pkgs.writeShellApplication {
    name = "nightly-build";
    runtimeInputs = [
      config.nix.package
      config.system.build.nixos-rebuild
      pkgs.git
      pkgs.jq
      pkgs.util-linux # runuser
    ];
    text = ''
      repo="github:Cody-W-Tucker/nix-config"
      roots=/nix/var/nix/gcroots/nightly-build
      mkdir -p "$roots"
      status=0

      # Pin one revision per run so every host builds the same commit.
      # Explicit returns: errexit is off when this runs inside an `if`.
      locked_ref() {
        local meta rev
        meta=$(nix flake metadata --refresh --json "$1") || return 1
        rev=$(jq -er '.locked.rev' <<<"$meta") || return 1
        echo "$repo?rev=$rev"
      }

      build() {
        local root=$1 ref=$2 host=$3
        echo "Building $host from $ref"
        nix build --keep-going --out-link "$roots/$root" \
          "$ref#nixosConfigurations.$host.config.system.build.toplevel"
      }

      # The NAS checkout may hold work that is deployed but not pushed. Only
      # switch when it is clean and fully pushed; otherwise build and leave the
      # running system alone. Read-only: never touches the checkout.
      checkout_is_pushed() {
        local changes ahead
        changes=$(as_owner status --porcelain) || return 1
        if [ -n "$changes" ]; then
          echo "Skipping NAS switch: $checkout has uncommitted changes:"
          echo "$changes"
          return 1
        fi
        ahead=$(as_owner rev-list --count '@{upstream}..HEAD') || return 1
        if [ "$ahead" -ne 0 ]; then
          echo "Skipping NAS switch: $checkout has $ahead unpushed commit(s)."
          return 1
        fi
      }
      as_owner() { runuser -u ${config.codyos.site.user.name} -- git -C "$checkout" "$@"; }
      checkout=/etc/nixos

      main=$(locked_ref "$repo")
      build beast "$main" beast || status=1
      if build nas "$main" nas; then
        if checkout_is_pushed; then
          nixos-rebuild switch --flake "$main#nas" || status=1
        fi
      else
        status=1
      fi

      # Pending flake-update PR (opened weekly by CI); build only, never switch.
      if pr=$(locked_ref "$repo?ref=update/flake-lock" 2>/dev/null); then
        build pr-beast "$pr" beast || status=1
        build pr-nas "$pr" nas || status=1
      else
        rm -f "$roots"/pr-*
      fi

      exit "$status"
    '';
  };
in
{
  # Builds run inside nix-daemon, not this unit, so the unit's Nice doesn't
  # reach them. Keep all NAS builds behind the services it hosts.
  nix = {
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
  };

  systemd.services.nightly-build = {
    description = "Build all hosts from main for the binary cache, then switch the NAS";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Like system.autoUpgrade: the switch inside this job must not restart or
    # stop the job itself.
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;
    environment.HOME = "/root";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nightlyBuild}/bin/nightly-build";
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "batch";
    };
  };

  systemd.timers.nightly-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00";
      RandomizedDelaySec = "15min";
      # Catch up after the NAS was off at 03:00.
      Persistent = true;
    };
  };
}
