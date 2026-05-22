# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

let
  # Default startup endpoint for the wg-quick peer below. `vpn-hop`
  # swaps this live at runtime; the value here is what reloads on
  # `systemctl restart wg-quick-nordlynx` or boot.
  nordlynxEndpoint = "180.149.231.154";
  nordlynxPort = 51820;

  # Live country-switcher. See `vpn-hop --help`.
  # NORDLYNX_PORT is the only Nix-side value the script needs; pass it via
  # env so scripts/vpn-hop.sh stays pure shell (editor highlighting, shellcheck).
  vpnHop = pkgs.writeShellApplication {
    name = "vpn-hop";
    runtimeInputs = with pkgs; [ curl jq wireguard-tools iproute2 ];
    text = ''
      export NORDLYNX_PORT=${toString nordlynxPort}
      ${builtins.readFile ./scripts/vpn-hop.sh}
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./firefox.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "markeeg";
  networking.networkmanager.enable = true;
  # wg-quick owns the nordlynx interface — keep NM from touching it.
  networking.networkmanager.unmanaged = [ "interface-name:nordlynx" ];

  # Declarative WiFi via NetworkManager keyfile profiles. The PSK is kept
  # out of the world-readable nix store: `$WIFI_HOME_PSK` is substituted
  # at activation time from /etc/nm-secrets.env (root:root 0400), which
  # must contain the single line `WIFI_HOME_PSK=<password>`.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ "/etc/nm-secrets.env" ];
    profiles.home = {
      connection = {
        id = "TP-Link_21EB";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = "TP-Link_21EB";
        mode = "infrastructure";
      };
      wifi-security = {
        auth-alg = "open";
        key-mgmt = "wpa-psk";
        psk = "$WIFI_HOME_PSK";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # systemd-resolved owns /etc/resolv.conf. wg-quick's `dns =` directive
  # below pushes Nord's resolver into it via resolvconf when the tunnel
  # comes up.
  services.resolved.enable = true;

  # NordVPN via native WireGuard (NordLynx). Pinned to nz94 — lowest-load
  # Auckland gateway at config time (load 21%). NordLynx publishes one
  # WireGuard public key for the whole NZ cluster, so rotating to another
  # NZ server only requires changing the endpoint IP (re-query
  # api.nordvpn.com/v1/servers/recommendations with country_id=156 and
  # technology wireguard_udp; the `station` field is the endpoint IP).
  #
  # Private key lives at /etc/nordlynx/private.key (root:root 0400) so the
  # secret never enters the nix store or git. Regenerate via
  # `curl -u token:<access_token> https://api.nordvpn.com/v1/users/services/credentials`
  # whenever NordVPN rotates the credential.
  #
  # DNS is set on the interface to Nord's resolver (103.86.96.100) so
  # name resolution rides the tunnel when up, without depending on any
  # host-level DNS config.
  networking.wg-quick.interfaces.nordlynx = {
    address = [ "10.5.0.2/32" ];
    privateKeyFile = "/etc/nordlynx/private.key";
    dns = [ "103.86.96.100" ];
    peers = [{
      publicKey = "P7Dv2WoopPHomMq6jnvwV2hnV2BnI/7LklaIUTEzSQ8=";
      allowedIPs = [ "0.0.0.0/0" "::/0" ];
      endpoint = "${nordlynxEndpoint}:${toString nordlynxPort}";
      persistentKeepalive = 25;
    }];
  };

  # VPN kill-switch. Independent of wg-quick's systemd unit lifecycle —
  # if the tunnel isn't up (boot window, service crash, wg-quick stopped
  # for any reason) the only egress permitted is: loopback, LAN/link-local,
  # DHCP, ICMPv6 neighbor discovery, and the WG handshake to the Nord
  # endpoint itself. Result: no clear-net leak even when nordlynx is gone.
  #
  # Switching to nftables changes the firewall backend; iptables still
  # works through the nft-backed shim, so wg-quick's own PostUp rules
  # continue to apply.
  networking.nftables.enable = true;
  networking.nftables.tables.killswitch = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority filter; policy drop;

        # Loopback and replies to flows we already permitted.
        oifname "lo" accept
        ct state established,related accept

        # LAN / link-local / multicast / broadcast (v4 + v6).
        ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16,
                   169.254.0.0/16, 224.0.0.0/4, 255.255.255.255 } accept
        ip6 daddr { fe80::/10, fc00::/7, ff00::/8 } accept

        # DHCP (v4 + v6) so we can still get a LAN lease pre-tunnel.
        udp dport { 67, 68, 546, 547 } accept

        # IPv6 neighbor discovery — required for IPv6 to work on any LAN.
        icmpv6 type { nd-router-solicit, nd-router-advert,
                      nd-neighbor-solicit, nd-neighbor-advert,
                      nd-redirect } accept

        # WireGuard handshake/keepalive on UDP/51820 to any destination,
        # so `vpn-hop <country>` can swap the peer to a different NordVPN
        # server live without rebuilding the firewall. The port itself
        # isn't a useful exfil channel (the other side has to speak the
        # WireGuard handshake or the packets achieve nothing), so the
        # accidental-leak protection this kill-switch exists for is
        # preserved.
        udp dport ${toString nordlynxPort} accept

        # Anything that's already been routed into the tunnel.
        oifname "nordlynx" accept
      }
    '';
  };

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_NZ.UTF-8";

  # Rewrite Ctrl+;/' (and Shift variants) to AltGr+;/' at the evdev layer so
  # the xkb keymap (see home.nix: wayland.windowManager.hyprland.input.kb_file)
  # produces ö/ä for Otso's Ctrl muscle memory. keyd operates below xkb in
  # the input pipeline, so this is compositor-agnostic. `G` in keyd action
  # syntax is the AltGr (Mode_switch / ISO_Level3_Shift) modifier.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        control = {
          semicolon  = "G-semicolon";
          apostrophe = "G-apostrophe";
        };
        "shift+control" = {
          semicolon  = "G-S-semicolon";
          apostrophe = "G-S-apostrophe";
        };
      };
    };
  };

  # Wayland compositor — Hyprland, launched via UWSM (systemd-managed session
  # target). The module pulls in xdg-desktop-portal-hyprland; the GTK portal
  # below covers file pickers and the GTK/GNOME-style portal calls.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Hyprland's portal doesn't implement FileChooser, so route file pickers /
    # settings to GTK and screen-capture to Hyprland explicitly.
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    };
  };

  # Login: greetd + tuigreet. The --cmd value mirrors what hyprland-uwsm.desktop
  # ships with so the session starts under UWSM exactly as a graphical DM would.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start -e -D Hyprland hyprland.desktop'";
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Firmware updates via LVFS (UEFI, SSD, dock, etc.). Run `fwupdmgr refresh`
  # then `fwupdmgr update` manually when you want to apply.
  services.fwupd.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Unlocks AMD microcode updates and firmware blobs assumed by hardware-configuration.nix.
  hardware.enableRedistributableFirmware = true;

  # Bluetooth — managed from a terminal via `bluetoothctl` (no tray applet).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Nix store maintenance: weekly GC of generations older than 14 days.
  # `auto-optimise-store` dedups during every build.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.settings.auto-optimise-store = true;


  # Wipe /tmp on boot — desktop with no encrypted swap, no reason to keep stale tmp.
  boot.tmp.cleanOnBoot = true;

  # The command-not-found DB shipped via nixpkgs is stale under flakes (built against
  # whatever nixpkgs the channel pointed at, not our pinned input). Disable to avoid
  # misleading "did you mean…" output.
  programs.command-not-found.enable = false;

  # Compressed RAM swap — low-friction memory pressure relief for a desktop.
  zramSwap.enable = true;

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.otso = {
    isNormalUser = true;
    description = "otso";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };


  programs.steam.enable = true;

  # Disable system sleep/suspend/hibernate entirely.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # fish.enable at system level installs shell completions and /etc/shells entry;
  # the user program config lives in home.nix — both are needed.
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  fonts.packages = with pkgs; [
    comic-mono
    noto-fonts           # modern Latin/Cyrillic/Greek/Arabic/etc — replaces DejaVu as default
    noto-fonts-cjk-sans  # proper CJK rendering; without it kanji/hanzi fall back to Unifont bitmaps
    liberation_ttf       # metric-compatible Arial/Times/Courier — pages that name those fonts directly will lay out correctly
  ];

  # Pin generic-family resolution so we don't depend on fontconfig priority order.
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Noto Sans" "Liberation Sans" ];
    serif     = [ "Noto Serif" "Liberation Serif" ];
    monospace = [ "Comic Mono" "Noto Sans Mono" ];
    emoji     = [ "Noto Color Emoji" ];
  };

  environment.systemPackages = with pkgs; [
    bat
    btop
    eza
    fd
    fzf
    jq
    nnn
    ripgrep
    tldr
    vpnHop
    zoxide
  ];

  # Pinned to install version; independent of home.stateVersion. See
  # https://nixos.org/manual/nixos/unstable/options#opt-system.stateVersion
  system.stateVersion = "25.11";

}
