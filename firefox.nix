{ ... }:

{
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
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
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
}
