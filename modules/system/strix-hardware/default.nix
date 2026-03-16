# Strix Halo hardware control modules
# Provides power management and performance tuning for AMD Ryzen AI MAX+ systems
{
  imports = [
    ./ryzenadj.nix
    ./tuning.nix
    ./ec-su-axb35.nix
  ];
}
