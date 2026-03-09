{ ... }:

{
  imports = [
    ./cli
    ./packages/scripts
  ];

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };
}
