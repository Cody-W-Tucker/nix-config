{ pkgs, ... }:

{
  codyos.harness.plugins.tokeneconomizer = {
    packages = [ pkgs.tokeneconomizer ];
    # Global plugin discovery loads this V1/V2-compatible plugin without passing
    # a single-file path through the deprecated V1 `plugin` setting; symlinking to
    # the bundle keeps `../scripts` and `../lib/tokeneconomizer` reachable from
    # `import.meta.url`.
    opencode.file = "${pkgs.tokeneconomizer}/tokeneconomizer/opencode/tokeneconomizer.ts";
    claudeCode.plugin = "${pkgs.tokeneconomizer}/tokeneconomizer";
  };
}
