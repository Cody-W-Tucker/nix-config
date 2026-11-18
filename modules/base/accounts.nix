{
  # Host-level account policy: immutable users and the shared groups. The codyt account
  # itself is the `user` class of den.aspects.codyt (modules/users/codyt.nix).
  den.aspects.accounts.nixos.users = {
    # Make passwords uneditable
    mutableUsers = false;
    groups.media = { };
    groups.documents = { };
  };
}
