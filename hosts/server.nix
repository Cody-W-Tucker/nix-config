{
  config,
  lib,
  inputs,
  ...
}:

# Home server / media / homelab CPU: i7-7000 RAM: 64GB GPU: Intel HD 630 Storage: 500GB NVMe + 4TB HDD

{
  imports = [
    ../modules/system/base.nix
    ../modules/server
    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-gpu-intel-kaby-lake
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    # VPN for media
    inputs.vpn-confinement.nixosModules.default
  ];

  # Home-manager configuration
  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
    };
    users.codyt = {
      imports = [
        ../users/cody/cli.nix
        ../secrets/home-secrets.nix
        inputs.nixvim.homeModules.nixvim
      ];
      home.enableNixpkgsReleaseCheck = false;
    };
  };

  # Bootloader
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [
      "kvm-intel"
      "i915"
    ];
    kernelParams = [ "i915.enable_guc=2" ];
    extraModulePackages = [ ];
  };

  # Networking
  networking = {
    hostName = "server";
    networkmanager.enable = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/c6c7b5c2-8edf-4aa5-9c6d-cbcd7498db1d";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/763D-AB92";
      fsType = "vfat";
    };
    "/mnt/media" = {
      device = "/dev/disk/by-uuid/27ddc2ef-8f21-401d-b9eb-3ed4541c16c9";
      fsType = "ext4";
    };
    "/mnt/dev/sr0" = {
      device = "/dev/sr0";
      fsType = "udf,iso9660";
      options = [
        "users"
        "noauto"
        "exec"
        "utf8"
      ];
    };
  };

  swapDevices = [ ];

  # Auto configure usb etc, when plugedin
  services.udisks2.enable = true;

  # NFS server for sharing media directory
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /mnt/media 192.168.1.20(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100)
  '';

  # Open NFS ports in firewall for local network
  networking.firewall.allowedTCPPorts = [
    2049
    111
  ];
  networking.firewall.allowedUDPPorts = [
    2049
    111
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Don't change this
  system.stateVersion = "23.11"; # Did you read the comment?

  # Tailscale - run: "sudo tailscale up --auth-key=KEY" with the key generated at https://login.tailscale.com/admin/machines/new-linux
  services.tailscale.enable = true;
}
