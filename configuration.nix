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
  vpnHop = pkgs.writeShellApplication {
    name = "vpn-hop";
    runtimeInputs = with pkgs; [ curl jq wireguard-tools iproute2 ];
    text = ''
      usage() {
          cat <<'EOF'
      Usage:
        vpn-hop                 Show current peer, handshake age, and exit IP.
        vpn-hop <country-code>  Switch to lowest-load server in that country.
                                country-code: 2-letter ISO code (fi, us, gb, jp, ...)
        vpn-hop reset           Restart wg-quick-nordlynx (reverts to declared peer).
      EOF
      }

      show_status() {
          echo "=== wg show nordlynx ==="
          sudo wg show nordlynx
          echo
          echo "=== exit IP ==="
          curl -sS --max-time 10 https://ipv4.icanhazip.com || echo "(check failed)"
      }

      wait_for_handshake() {
          local n hsage
          for n in 1 2 3 4 5; do
              sleep 1
              hsage=$(sudo wg show nordlynx latest-handshakes | awk 'NR==1 {print $2}')
              if [ -n "$hsage" ] && [ "$hsage" -gt 0 ]; then
                  echo "Handshake established after $n s."
                  curl -sS --max-time 10 https://ipv4.icanhazip.com || true
                  return 0
              fi
          done
          echo "No handshake after 5s. Run 'sudo wg show nordlynx' to diagnose." >&2
          return 1
      }

      if [ $# -eq 0 ]; then
          show_status
          exit 0
      fi

      case "$1" in
          -h|--help|help) usage; exit 0 ;;
          reset)
              echo "Restarting wg-quick-nordlynx..."
              sudo systemctl restart wg-quick-nordlynx
              wait_for_handshake
              exit $?
              ;;
      esac

      code=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
      if ! [[ "$code" =~ ^[A-Z][A-Z]$ ]]; then
          echo "Expected a 2-letter country code (got '$1')." >&2
          usage >&2
          exit 2
      fi

      if ! ip link show nordlynx >/dev/null 2>&1; then
          echo "nordlynx interface not present. Run: sudo systemctl start wg-quick-nordlynx" >&2
          exit 1
      fi

      country_id=$(curl -fsS --max-time 10 \
          'https://api.nordvpn.com/v1/servers/countries' \
          | jq --arg code "$code" -r '.[] | select(.code == $code) | .id' \
          | head -n1)
      if [ -z "$country_id" ]; then
          echo "Unknown country code: $code" >&2
          exit 1
      fi

      rec=$(curl -fsS --max-time 10 \
          "https://api.nordvpn.com/v1/servers/recommendations?filters%5Bcountry_id%5D=$country_id&filters%5Bservers_technologies%5D%5Bidentifier%5D=wireguard_udp&limit=1")

      endpoint=$(printf '%s' "$rec" | jq -r '.[0].station')
      hostname=$(printf '%s' "$rec" | jq -r '.[0].hostname')
      load=$(printf '%s' "$rec" | jq -r '.[0].load')
      pubkey=$(printf '%s' "$rec" | jq -r '.[0].technologies[] | select(.identifier=="wireguard_udp") | .metadata[] | select(.name=="public_key") | .value')

      if [ -z "$endpoint" ] || [ "$endpoint" = "null" ] || [ -z "$pubkey" ] || [ "$pubkey" = "null" ]; then
          echo "API returned no usable server for $code." >&2
          exit 1
      fi

      old_peer=$(sudo wg show nordlynx peers | head -n1 || true)

      echo "Switching to $hostname ($endpoint, load $load%)..."

      sudo wg set nordlynx peer "$pubkey" \
          allowed-ips 0.0.0.0/0,::/0 \
          endpoint "$endpoint:${toString nordlynxPort}" \
          persistent-keepalive 25

      if [ -n "$old_peer" ] && [ "$old_peer" != "$pubkey" ]; then
          sudo wg set nordlynx peer "$old_peer" remove
      fi

      wait_for_handshake
    '';
  };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "markeeg";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_NZ.UTF-8";
    LC_IDENTIFICATION = "en_NZ.UTF-8";
    LC_MEASUREMENT = "en_NZ.UTF-8";
    LC_MONETARY = "en_NZ.UTF-8";
    LC_NAME = "en_NZ.UTF-8";
    LC_NUMERIC = "en_NZ.UTF-8";
    LC_PAPER = "en_NZ.UTF-8";
    LC_TELEPHONE = "en_NZ.UTF-8";
    LC_TIME = "en_NZ.UTF-8";
  };

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
  };

  # Login: greetd + tuigreet. The --cmd value mirrors what hyprland-uwsm.desktop
  # ships with so the session starts under UWSM exactly as a graphical DM would.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start -e -D Hyprland hyprland.desktop'";
      user = "greeter";
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
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

  # Nix store maintenance: weekly GC of generations older than 30 days + dedup.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  # Compressed RAM swap — low-friction memory pressure relief for a desktop.
  zramSwap.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.otso = {
    isNormalUser = true;
    description = "otso";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      OfferToSaveLogins = false;
      DisableFormHistory = true;
      DisableFirefoxAccounts = true;
      DisableAccounts = true;
      DisableProfileImport = true;
      DisableSetDesktopBackground = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      PasswordManagerEnabled = false;
      NetworkPrediction = false;
      SearchSuggestEnabled = false;
      TranslateEnabled = false;
      DisableDefaultBrowserAgent = true;
      BackgroundAppUpdate = false;
      AppAutoUpdate = false;
      PostQuantumKeyAgreementEnabled = true;
      HttpsOnlyMode = "force_enabled";
      SearchEngines.Default = "DuckDuckGo";
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://base.dns.mullvad.net/dns-query";
        Locked = true;
        Fallback = true;
      };
      UserMessaging = {
        WhatsNew = false;
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
        Locked = true;
      };
      FirefoxHome = {
        Search = true;
        TopSites = true;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
        Locked = true;
      };
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = true;
      };
      ContentAnalysis = {
        Enabled = false;
      };
      Permissions = {
        Location = {
          BlockNewRequests = true;
          Locked = true;
        };
        Notifications = {
          BlockNewRequests = true;
          Locked = true;
        };
        Camera = {
          BlockNewRequests = true;
          Locked = true;
        };
        Microphone = {
          BlockNewRequests = true;
          Locked = true;
        };
        VirtualReality = {
          BlockNewRequests = true;
          Locked = true;
        };
        Autoplay = {
          Default = "block-audio-video";
          Locked = true;
        };
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "skipredirect@sblask" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/skip-redirect/latest.xpi";
          installation_mode = "force_installed";
          private_browsing = true;
        };
      };
      Preferences = {
        "browser.contentblocking.category" = {
          Value = "strict";
          Status = "locked";
        };
        "privacy.globalprivacycontrol.enabled" = {
          Value = true;
          Status = "locked";
        };
        "browser.discovery.enabled" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.enable" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.enabled" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.shortcuts" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.shortcuts.custom" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.menu" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.page" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.page.menuBadge" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.sidebar" = {
          Value = false;
          Status = "locked";
        };
        "browser.ml.chat.provider" = {
          Value = "";
          Status = "locked";
        };
        "browser.ml.linkPreview.enabled" = {
          Value = false;
          Status = "locked";
        };
        "browser.tabs.groups.smart.enabled" = {
          Value = false;
          Status = "locked";
        };
        "extensions.ml.enabled" = {
          Value = false;
          Status = "locked";
        };
        "pdfjs.enableAltText" = {
          Value = false;
          Status = "locked";
        };
        "pdfjs.enableAltTextModelDownload" = {
          Value = false;
          Status = "locked";
        };
        "browser.translations.enable" = {
          Value = false;
          Status = "locked";
        };
        "browser.translations.automaticallyPopup" = {
          Value = false;
          Status = "locked";
        };

        # Telemetry backing prefs (defence-in-depth alongside DisableTelemetry policy)
        "datareporting.policy.dataSubmissionEnabled" = { Value = false; Status = "locked"; };
        "datareporting.healthreport.uploadEnabled" = { Value = false; Status = "locked"; };
        "datareporting.usage.uploadEnabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.unified" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.server" = { Value = "data:,"; Status = "locked"; };
        "toolkit.telemetry.archive.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.newProfilePing.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.shutdownPingSender.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.updatePing.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.bhrPing.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.firstShutdownPing.enabled" = { Value = false; Status = "locked"; };
        "toolkit.telemetry.coverage.opt-out" = { Value = true; Status = "locked"; };
        "toolkit.coverage.opt-out" = { Value = true; Status = "locked"; };
        "toolkit.coverage.endpoint.base" = { Value = ""; Status = "locked"; };
        "browser.search.serpEventTelemetry.enabled" = { Value = false; Status = "locked"; };
        "browser.ping-centre.telemetry" = { Value = false; Status = "locked"; };
        "browser.places.interactions.enabled" = { Value = false; Status = "locked"; };

        # Crash reporter
        "breakpad.reportURL" = { Value = ""; Status = "locked"; };
        "browser.tabs.crashReporting.sendReport" = { Value = false; Status = "locked"; };
        "browser.crashReports.unsubmittedCheck.enabled" = { Value = false; Status = "locked"; };
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = { Value = false; Status = "locked"; };

        # Normandy / Shield / experiments
        "app.normandy.enabled" = { Value = false; Status = "locked"; };
        "app.normandy.api_url" = { Value = ""; Status = "locked"; };
        "app.shield.optoutstudies.enabled" = { Value = false; Status = "locked"; };
        "messaging-system.rsexperimentloader.enabled" = { Value = false; Status = "locked"; };
        "nimbus.debug" = { Value = false; Status = "locked"; };
        "network.trr.confirmation_telemetry_enabled" = { Value = false; Status = "locked"; };

        # asrouter / CFR / in-app recommendation engine
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.asrouter.providers.cfr" = { Value = ""; Status = "locked"; };
        "browser.newtabpage.activity-stream.asrouter.providers.message-groups" = { Value = ""; Status = "locked"; };
        "browser.newtabpage.activity-stream.asrouter.providers.whats-new-panel" = { Value = ""; Status = "locked"; };
        "browser.newtabpage.activity-stream.feeds.snippets" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.feeds.section.topstories" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.feeds.section.highlights" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.feeds.discoverystreamfeed" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.feeds.telemetry" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.telemetry" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.showSponsored" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.showWeather" = { Value = false; Status = "locked"; };
        "browser.newtabpage.activity-stream.system.showWeather" = { Value = false; Status = "locked"; };
        "browser.topsites.contile.enabled" = { Value = false; Status = "locked"; };
        "browser.topsites.useRemoteSetting" = { Value = false; Status = "locked"; };

        # Shopping / Fakespot / Review Checker
        "browser.shopping.experience2023.enabled" = { Value = false; Status = "locked"; };
        "browser.shopping.experience2023.optedIn" = { Value = 2; Status = "locked"; };
        "browser.shopping.experience2023.active" = { Value = false; Status = "locked"; };
        "browser.shopping.experience2023.autoOpen.enabled" = { Value = false; Status = "locked"; };
        "browser.shopping.experience2023.autoOpen.userEnabled" = { Value = false; Status = "locked"; };
        "browser.shopping.experience2023.ads.enabled" = { Value = false; Status = "locked"; };
        "browser.shopping.experience2023.ads.userEnabled" = { Value = false; Status = "locked"; };
        "browser.shopping.experience2023.survey.enabled" = { Value = false; Status = "locked"; };

        # Mozilla VPN / Monitor / "More from Mozilla" cross-promo
        "browser.vpn_promo.enabled" = { Value = false; Status = "locked"; };
        "browser.contentblocking.report.vpn.enabled" = { Value = false; Status = "locked"; };
        "browser.contentblocking.report.hide_vpn_banner" = { Value = true; Status = "locked"; };
        "browser.contentblocking.report.vpn_platforms" = { Value = ""; Status = "locked"; };
        "browser.contentblocking.report.monitor.enabled" = { Value = false; Status = "locked"; };
        "browser.contentblocking.report.lockwise.enabled" = { Value = false; Status = "locked"; };
        "browser.preferences.moreFromMozilla" = { Value = false; Status = "locked"; };
        "browser.promo.focus.enabled" = { Value = false; Status = "locked"; };
        "browser.promo.pin.enabled" = { Value = false; Status = "locked"; };
        "browser.promo.cookiebanners.enabled" = { Value = false; Status = "locked"; };

        # Onboarding / "What's New" / upgrade dialogs
        "browser.aboutwelcome.enabled" = { Value = false; Status = "locked"; };
        "browser.startup.homepage_override.mstone" = { Value = "ignore"; Status = "locked"; };
        "startup.homepage_welcome_url" = { Value = ""; Status = "locked"; };
        "startup.homepage_welcome_url.additional" = { Value = ""; Status = "locked"; };
        "startup.homepage_override_url" = { Value = ""; Status = "locked"; };
        "browser.messaging-system.whatsNewPanel.enabled" = { Value = false; Status = "locked"; };
        "browser.startup.upgradeDialog.enabled" = { Value = false; Status = "locked"; };

        # Urlbar feature gates (Suggest widgets and friends)
        "browser.urlbar.quicksuggest.enabled" = { Value = false; Status = "locked"; };
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = { Value = false; Status = "locked"; };
        "browser.urlbar.suggest.quicksuggest.sponsored" = { Value = false; Status = "locked"; };
        "browser.urlbar.trending.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.recentsearches.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.clipboard.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.addons.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.mdn.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.weather.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.yelp.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.fakespot.featureGate" = { Value = false; Status = "locked"; };
        "browser.urlbar.suggest.shopping" = { Value = false; Status = "locked"; };
        "browser.urlbar.showSearchTerms.enabled" = { Value = false; Status = "locked"; };
        "browser.urlbar.groupLabels.enabled" = { Value = false; Status = "locked"; };
        "browser.search.suggest.enabled" = { Value = false; Status = "locked"; };
        "browser.urlbar.suggest.searches" = { Value = false; Status = "locked"; };
        "browser.formfill.enable" = { Value = false; Status = "locked"; };
        "browser.search.update" = { Value = false; Status = "locked"; };

        # Sidebar revamp (FF131+) — kill the curated tool launcher
        "sidebar.revamp" = { Value = false; Status = "locked"; };
        "sidebar.verticalTabs" = { Value = false; Status = "locked"; };
        "sidebar.main.tools" = { Value = ""; Status = "locked"; };

        # Prefetch / predictor / speculative connections
        "network.prefetch-next" = { Value = false; Status = "locked"; };
        "network.dns.disablePrefetch" = { Value = true; Status = "locked"; };
        "network.dns.disablePrefetchFromHTTPS" = { Value = true; Status = "locked"; };
        "network.predictor.enabled" = { Value = false; Status = "locked"; };
        "network.predictor.enable-prefetch" = { Value = false; Status = "locked"; };
        "network.http.speculative-parallel-limit" = { Value = 0; Status = "locked"; };
        "browser.urlbar.speculativeConnect.enabled" = { Value = false; Status = "locked"; };
        "browser.places.speculativeConnect.enabled" = { Value = false; Status = "locked"; };

        # Web push (kill connection to autopush.services.mozilla.com)
        "dom.push.enabled" = { Value = false; Status = "locked"; };
        "dom.push.serverURL" = { Value = ""; Status = "locked"; };
        "dom.battery.enabled" = { Value = false; Status = "locked"; };

        # Captive portal / connectivity probes (no phoning detectportal.firefox.com)
        "network.captive-portal-service.enabled" = { Value = false; Status = "locked"; };
        "captivedetect.canonicalURL" = { Value = ""; Status = "locked"; };
        "network.connectivity-service.enabled" = { Value = false; Status = "locked"; };
        "network.connectivity-service.IPv4.url" = { Value = ""; Status = "locked"; };
        "network.connectivity-service.IPv6.url" = { Value = ""; Status = "locked"; };

        # Geolocation (MLS retired; default endpoint is dead anyway)
        "geo.enabled" = { Value = false; Status = "locked"; };
        "geo.provider.use_geoclue" = { Value = false; Status = "locked"; };
        "geo.provider.network.url" = { Value = ""; Status = "locked"; };
        "browser.region.network.url" = { Value = ""; Status = "locked"; };
        "browser.region.update.enabled" = { Value = false; Status = "locked"; };

        # Safe Browsing: keep phishing/malware on, kill only the executable-hash upload
        "browser.safebrowsing.downloads.remote.enabled" = { Value = false; Status = "locked"; };
        "browser.safebrowsing.downloads.remote.url" = { Value = ""; Status = "locked"; };

        # DoH defence-in-depth (Mullvad already set via policy)
        "network.trr.send_user-agent_headers" = { Value = false; Status = "locked"; };
        "doh-rollout.disable-heuristics" = { Value = true; Status = "locked"; };
        "doh-rollout.skipHeuristicsCheck" = { Value = true; Status = "locked"; };

        # Firefox Accounts / Sync backing prefs
        "identity.fxaccounts.enabled" = { Value = false; Status = "locked"; };
        "identity.fxaccounts.toolbar.enabled" = { Value = false; Status = "locked"; };
        "identity.fxaccounts.pairing.enabled" = { Value = false; Status = "locked"; };
        "browser.tabs.firefox-view.notify-for-tabs" = { Value = false; Status = "locked"; };

        # Extension/addon discovery surfaces
        "extensions.htmlaboutaddons.recommendations.enabled" = { Value = false; Status = "locked"; };
        "extensions.getAddons.showPane" = { Value = false; Status = "locked"; };
        "extensions.pocket.enabled" = { Value = false; Status = "locked"; };

        # Beacon / ping tracking
        "browser.send_pings" = { Value = false; Status = "locked"; };

        # WebRTC: minor IP-leak tightening (does NOT break video conferencing)
        "media.peerconnection.ice.default_address_only" = { Value = true; Status = "locked"; };
        "media.peerconnection.ice.proxy_only_if_behind_proxy" = { Value = true; Status = "locked"; };
      };
      "3rdparty" = {
        Extensions = {
          "uBlock0@raymondhill.net" = {
            adminSettings = {
              userSettings = {
                importedLists = [
                  "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt"
                ];
              };
              selectedFilterLists = [
                "user-filters"
                "ublock-filters"
                "ublock-badware"
                "ublock-privacy"
                "ublock-unbreak"
                "ublock-quick-fixes"
                "easylist"
                "easyprivacy"
                "urlhaus-1"
                "plowe-0"
                "adguard-spyware-url"
                "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/LegitimateURLShortener.txt"
              ];
            };
          };
        };
      };
    };
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
  fonts.packages = [ pkgs.comic-mono ];

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
