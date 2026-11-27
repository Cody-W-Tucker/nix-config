{
  den.default.nixos = {
    time.timeZone = "America/Chicago";
    i18n.defaultLocale = "en_US.UTF-8";

    users = {
      mutableUsers = false;
      groups.media = { };
      groups.documents = { };
    };

    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
    ];
  };
}
