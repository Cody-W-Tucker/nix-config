# Beast hardware: disks, initrd/kernel modules, and device quirks for this
# machine. Host policy lives in default.nix.
_:

{
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [
      "kvm-intel"
      "btusb"
    ];
    extraModprobeConfig = ''
      options mt7925e disable_aspm=Y
      options btusb enable_autosuspend=n reset=1
    '';
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/36FA-44EF";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };
}
