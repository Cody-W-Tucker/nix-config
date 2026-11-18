# Wayland desktop settings for NVIDIA GPUs. Part of the desktop profile, which only hosts
# that include den.aspects.nvidia (modules/hardware/nvidia.nix) use.
_:

{
  environment = {
    # NVIDIA-specific environment variables
    sessionVariables = {
      # ---------------------------
      # Nvidia & Graphics Drivers
      # ---------------------------
      LIBVA_DRIVER_NAME = "nvidia";
      NVD_BACKEND = "direct";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __GL_GSYNC_ALLOWED = "1";
      __GL_VRR_ALLOWED = "0";
      # Required for Firefox/Zen hardware acceleration with NVIDIA
      MOZ_DISABLE_RDD_SANDBOX = "1";
    };
  };
}
