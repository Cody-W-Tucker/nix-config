{ config, pkgs, lib, ... }: {
  options.packages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    description = "Custom packages";
  };

  config = {
    packages = {
      bibata-hyprcursor = pkgs.callPackage ./bibata-hyprcursor { };
    };
  };
}
