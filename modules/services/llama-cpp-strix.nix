{
  config,
  lib,
  pkgs,
  ...
}:

let
  # llama-cpp with Strix Halo (gfx1151) optimizations
  # Based on AMD Strix Halo Toolboxes configuration
  llama-cpp-strix =
    (pkgs.llama-cpp.override {
      rocmSupport = true;
    }).overrideAttrs
      (oldAttrs: {
        # Strix Halo (gfx1151) specific build flags
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          "-DAMDGPU_TARGETS=gfx1151"
          "-DLLAMA_HIP_UMA=ON"
          "-DGGML_RPC=ON"
        ];

        # Build the web UI and then add our custom flags
        preConfigure = ''
          ${oldAttrs.preConfigure or "# No original preConfigure"}

          # Add ROCm 7+ performance regression workaround
          # See: https://github.com/kyuz0/amd-strix-halo-toolboxes/issues/45
          cmakeFlagsArray+=(
            "-DCMAKE_HIP_FLAGS=--rocm-path=${pkgs.rocmPackages.rocm-core} -mllvm --amdgpu-unroll-threshold-local=600"
          )
        '';

        # Ensure HIP environment is set up correctly
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
          pkgs.rocmPackages.clr
        ];
      });
in
{
  services.llama-cpp = {
    enable = true;

    # Use ROCm-enabled package with Strix Halo specific optimizations
    package = llama-cpp-strix;

    # Default model path (user should override)
    model = lib.mkDefault "/var/lib/llama-cpp/models/model.gguf";

    # Strix Halo optimized flags:
    # --flash-attn on: Flash attention (always use on Strix Halo)
    # --no-mmap: Required for UMA to avoid crashes
    # -ngl 999: Offload all layers to GPU
    extraFlags = lib.mkDefault [
      "--flash-attn"
      "on"
      "--no-mmap"
      "--n-gpu-layers"
      "999"
    ];

    # Bind to all interfaces for remote access
    host = lib.mkDefault "0.0.0.0";
    port = lib.mkDefault 8080;
  };

  # Create model directory
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-cpp/models 0755 root root -"
  ];

  # Environment variables for ROCm/HIP
  environment.sessionVariables = {
    # Required for Strix Halo gfx1151 detection
    HSA_OVERRIDE_GFX_VERSION = "11.5.1";
    # Ensure ROCm path is available
    ROCM_PATH = "${pkgs.rocmPackages.rocm-core}";
    HIP_PATH = "${pkgs.rocmPackages.rocm-core}";
  };
}
