{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  crg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code-review-graph;
  deja = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu;
  dejaMcp = pkgs.writeShellApplication {
    name = "deja-mcp";
    runtimeInputs = [ pkgs.sqlite ];
    text = "exec ${lib.getExe deja} mcp";
  };
  qmd = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd;
  mcpRegistry = {
    deja.command = lib.getExe dejaMcp;
    # QMD runs here, as a gateway child, not in the bubblewrap terminal: bwrap
    # remounts binds nodev, so /dev/nvidia* can never be opened in the sandbox.
    # GPU backend is Vulkan (NVIDIA ICD under /run/opengl-driver). The packaged
    # CUDA prebuilt needs libcudart.so.13/libcublas.so.13, which are not on the host.
    qmd = {
      command = lib.getExe qmd;
      args = [ "mcp" ];
      env = {
        QMD_LLAMA_GPU = "vulkan";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
        XDG_CONFIG_HOME = "/home/codyt/.config";
        XDG_CACHE_HOME = "/home/codyt/.cache";
      };
    };
    karakeep = {
      command = lib.getExe' pkgs.nodejs "npx";
      args = [
        "-y"
        "@karakeep/mcp"
      ];
      env.KARAKEEP_API_ADDR = "http://127.0.0.1:3005";
      env.KARAKEEP_API_KEY = "\${KARAKEEP_API_KEY}";
    };
  };
in
{
  config = {
    # Default profile only: expose selected servers so unrelated MCP schemas
    # and tools never enter its prompt surface.
    services.hermes-agent = {
      extraPackages = [ crg ];
      mcpServers = {
        inherit (mcpRegistry) karakeep deja qmd;
      };
    };
  };
}
