{
  imports = [
    ./cli
  ];

  config = {

    # Keyboard
    home.keyboard = {
      layout = "us";
      model = "pc105";
    };

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "24.05";
  };
}
