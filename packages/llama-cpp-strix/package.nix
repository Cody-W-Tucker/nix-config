# llama-cpp with Strix Halo (gfx1151) optimizations
# Based on AMD Strix Halo Toolboxes configuration

{ pkgs }:

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
  })
