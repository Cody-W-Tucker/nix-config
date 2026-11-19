{
  # Settings that belong to no feature. Keep this small: anything with a name of its
  # own gets a feature file that registers itself via `den.default.includes`.
  den.default.nixos = {
    # Locale and timezone.
    time.timeZone = "America/Chicago";
    i18n.defaultLocale = "en_US.UTF-8";

    # Host-level account policy: immutable users and the shared groups. The codyt
    # account itself is the `user` class of den.aspects.codyt (modules/users/codyt.nix).
    users = {
      # Make passwords uneditable
      mutableUsers = false;
      groups.media = { };
      groups.documents = { };
    };

    # https://emudhra.we-have-a-problem.com/
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
    ];
  };
}
