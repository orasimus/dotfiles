{ pkgs, ... }:

{
  virtualisation.waydroid.enable = true;

  # Waydroid uses the nftables-aware package automatically because vpn.nix
  # enables networking.nftables. Keep a few helpers available for setup,
  # Play Services registration, and later location forwarding.
  environment.systemPackages = with pkgs; [
    android-tools
    waydroid-helper
    wl-clipboard
  ];

  services.geoclue2.enable = true;

  # Android system image, LXC config, and installed app data. This host rolls
  # root back on boot, so Waydroid's system state must live under /persist.
  environment.persistence."/persist".directories = [
    "/var/lib/waydroid"
  ];
}
