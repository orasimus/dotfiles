{ ... }:

{
  # One age identity is the only reinstall-time bootstrap secret. Keep it on
  # /persist so the wiped root never owns the decryption key.
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";

  sops.secrets."passwords/otso" = {
    neededForUsers = true;
  };

  sops.secrets."passwords/root" = {
    neededForUsers = true;
  };

  sops.secrets."network/nm-secrets.env" = {
    mode = "0400";
  };

  sops.secrets."network/nordlynx-private.key" = {
    mode = "0400";
  };

  sops.secrets."gocryptfs/vault-password" = {
    owner = "otso";
    group = "users";
    mode = "0400";
  };

  sops.secrets."ssh/github" = {
    path = "/home/otso/.ssh/github";
    owner = "otso";
    group = "users";
    mode = "0400";
  };

  sops.secrets."ssh/kapsi" = {
    path = "/home/otso/.ssh/kapsi";
    owner = "otso";
    group = "users";
    mode = "0400";
  };
}
