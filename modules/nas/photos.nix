{
  services.immich = {
    enable = true;
    port = 2283;
    host = "localhost";
    mediaLocation = "/mnt/backup/photos";
    group = "media";

    # Expose GPU 0 to Immich ML via narrow NVIDIA device allowlist.
    # Setting a non-empty accelerationDevices makes PrivateDevices=false
    # (default [] means PrivateDevices=true, blocking all GPU access).
    machine-learning.environment = {
      CUDA_VISIBLE_DEVICES = "0";
    };
    accelerationDevices = [
      "/dev/nvidiactl"
      "/dev/nvidia0"
      "/dev/nvidia-uvm"
    ];
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
    "media"
  ];

  # NGINX
  services.nginx.virtualHosts."photos.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:2283";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
    kTLS = true;
  };

  # Backup photos to workstation hard drive
  # services.borgbackup.jobs.photos = {
  #   user = "codyt";
  #   group = "media";
  #   paths = "/mnt/media/Photos/originals";
  #   encryption.mode = "none";
  #   environment.BORG_RSH = "ssh -i /home/codyt/.ssh/id_ed25519";
  #   repo = "codyt@192.168.1.238:/mnt/backup/Photos";
  #   compression = "lz4";
  #   startAt = "daily";
  # };
}
