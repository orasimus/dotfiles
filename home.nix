{ config, pkgs, ... }:
let
  # Standard US layout with AltGr as level-3 shifter, plus ö/ä on AC10/AC11.
  # Combined with services.keyd (configuration.nix) which rewrites Ctrl+;/'
  # → AltGr+;/' below xkb, this yields Ctrl+; → ö, Ctrl+' → ä, +Shift for
  # capitals. Consumed by Hyprland's input.kb_file below.
  umlautKeymap = pkgs.writeText "us-umlauts.xkb" ''
    xkb_keymap {
        xkb_keycodes { include "evdev+aliases(qwerty)" };
        xkb_types    { include "complete" };
        xkb_compat   { include "complete" };
        xkb_symbols {
            include "pc+us+inet(evdev)+level3(ralt_switch)"
            override key <AC10> {
                type[Group1] = "FOUR_LEVEL",
                symbols[Group1] = [ semicolon,  colon,    odiaeresis, Odiaeresis ]
            };
            override key <AC11> {
                type[Group1] = "FOUR_LEVEL",
                symbols[Group1] = [ apostrophe, quotedbl, adiaeresis, Adiaeresis ]
            };
        };
        xkb_geometry { include "pc(pc105)" };
    };
  '';
in
{
  imports = [
    ./harri.nix
  ];
  home.username = "otso";
  home.homeDirectory = "/home/otso";
  home.stateVersion = "25.11";  # original install version — do not bump, independent of system.stateVersion

  # user-level packages (as opposed to system-wide). Packages with declarative
  # config live under programs.* below (fuzzel, mpv, btop, tealdeer, nnn,
  # ripgrep) — they're installed implicitly by their respective modules.
  home.packages = with pkgs; [
    chafa
    heroic
    qbittorrent
    spotify
    sublime-merge
  ];

  # Impermanence: bind-mount the listed paths from /persist/home/otso into ~
  # on each boot. The wiped @root subvolume starts each boot empty; without
  # these declarations the listed paths would vanish on every reboot.
  #
  # What's deliberately NOT here:
  #   - ~/.cache/*           — regeneratable
  #   - ~/.config/{btop,fish,fuzzel,git,helix,hypr,kitty,nnn,tealdeer,...}
  #                          — all owned by home-manager, recreated as
  #                            symlinks into /nix/store on every activation
  #
  # Things to be aware of:
  #   - The bind-mount targets are created at boot by systemd mount units
  #     before home-manager runs, so HM activation sees the persisted dirs
  #     in place and won't try to overwrite them.
  #   - For each path that doesn't yet exist under /persist/home/otso, the
  #     module creates an empty owned-by-otso dir/file at first boot. Pre-seed
  #     them before reboot if you want existing data preserved (separate
  #     /mnt/old → /persist migration step).
  # The key here is the persistent storage root, NOT including the user's home
  # directory — the module prefixes ~/ to every relative entry automatically.
  home.persistence."/persist" = {
    directories = [
      # personal files
      "Documents"
      "Downloads"
      "Pictures"
      "Music"
      "Videos"
      "Projects"
      "Public"
      "Games"
      ".dotfiles"
      ".ssh"

      # app logins / state
      ".config/discord"
      ".local/share/Steam"
      ".steam"
      ".config/spotify"
      ".config/heroic"
      ".config/qBittorrent"
      ".local/share/qBittorrent"
      ".config/ZapZap"
      ".local/share/ZapZap"
      ".config/sublime-merge"
      ".config/mozilla/firefox"

      # Claude Code state (sessions, memory, plans)
      ".claude"

      # shell / runtime
      ".local/share/fish"
      ".local/state/wireplumber"
    ];

    files = [
      ".claude.json"
      ".bash_history"
    ];
  };

  programs.bat.enable = true;

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_mocha";
      theme_background = false;
      vim_keys = true;
      update_ms = 1500;
    };
  };
  # btop reads themes from $XDG_CONFIG_HOME/btop/themes/<name>.theme. Drop the
  # Catppuccin Mocha palette in there so color_theme above resolves.
  xdg.configFile."btop/themes/catppuccin_mocha.theme".text = ''
    theme[main_bg]="#1e1e2e"
    theme[main_fg]="#cdd6f4"
    theme[title]="#cdd6f4"
    theme[hi_fg]="#f5c2e7"
    theme[selected_bg]="#585b70"
    theme[selected_fg]="#f5c2e7"
    theme[inactive_fg]="#7f849c"
    theme[graph_text]="#f5e0dc"
    theme[meter_bg]="#45475a"
    theme[proc_misc]="#f5e0dc"
    theme[cpu_box]="#cba6f7"
    theme[mem_box]="#a6e3a1"
    theme[net_box]="#eba0ac"
    theme[proc_box]="#89b4fa"
    theme[div_line]="#7f849c"
    theme[temp_start]="#a6e3a1"
    theme[temp_mid]="#f9e2af"
    theme[temp_end]="#f38ba8"
    theme[cpu_start]="#94e2d5"
    theme[cpu_mid]="#89dceb"
    theme[cpu_end]="#b4befe"
    theme[free_start]="#cba6f7"
    theme[free_mid]="#b4befe"
    theme[free_end]="#89b4fa"
    theme[cached_start]="#89dceb"
    theme[cached_mid]="#74c7ec"
    theme[cached_end]="#89b4fa"
    theme[available_start]="#f9e2af"
    theme[available_mid]="#fab387"
    theme[available_end]="#eba0ac"
    theme[used_start]="#a6e3a1"
    theme[used_mid]="#94e2d5"
    theme[used_end]="#74c7ec"
    theme[download_start]="#89b4fa"
    theme[download_mid]="#cba6f7"
    theme[download_end]="#f5c2e7"
    theme[upload_start]="#a6e3a1"
    theme[upload_mid]="#94e2d5"
    theme[upload_end]="#74c7ec"
    theme[process_start]="#74c7ec"
    theme[process_mid]="#cba6f7"
    theme[process_end]="#f5c2e7"
  '';

  programs.claude-code = {
    enable = true;
    settings = {
      model = "opus";
    };
    mcpServers = {
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        type = "stdio";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.discord.enable = true;

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [ "--group-directories-first" ];
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      asenna = "sudo nixos-rebuild switch --flake ~/.dotfiles#markeeg";
      cat = "bat";
    };
    functions.fish_greeting = "";
  };

  # App launcher — SUPER+D in Hyprland. Catppuccin Mocha to match kitty.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "kitty";
        layer = "overlay";
        font = "Comic Mono:size=12";
      };
      colors = {
        background = "1e1e2eff";
        text = "cdd6f4ff";
        match = "f5c2e7ff";
        selection = "585b70ff";
        selection-text = "cdd6f4ff";
        selection-match = "f5c2e7ff";
        border = "b4befeff";
      };
      border = {
        width = 2;
        radius = 4;
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Otso Rasimus";
        email = "orasimus@gmail.com";
      };
      core.editor = "hx";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "catppuccin_mocha";
      editor.soft-wrap.enable = true;
    };
  };

  # Lockscreen — plain black background, password input centred. Expand later.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
      };
      background = [
        {
          monitor = "";
          color = "rgba(0, 0, 0, 1.0)";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "20%, 5%";
          position = "0, -20";
          halign = "center";
          valign = "center";
          fade_on_empty = false;
          placeholder_text = "Password";
        }
      ];
    };
  };

  programs.kitty = {
    enable = true;
    keybindings = {
      # In a nixi session, focus the asenna pane and send `asenna` to it.
      # The pane is tagged var:role=asenna in the session file below.
      # `focus_matching_window` is not a built-in action; matching by
      # criteria requires the remote_control action (needs allow_remote_control).
      # `send_text` (the built-in action, not `remote_control send-text`)
      # interprets escape sequences, so \x03 sends Ctrl+C to clear any
      # pending input / interrupt a running command before submitting.
      # Split into two send_text calls so the \x03 (Ctrl+C) escape can't
      # absorb the following `a` as a third hex digit.
      "ctrl+shift+a" = "combine | remote_control focus-window --match var:role=asenna | send_text all \\x03 | send_text all asenna\\n";
    };
    themeFile = "Catppuccin-Mocha";
    settings = {
      font_family = "Comic Mono";
      confirm_os_window_close = 0;
      # Restrict the kitty control protocol to the abstract socket below — keeps
      # the ctrl+shift+a chord working without exposing the API to any other
      # process in the session.
      allow_remote_control = "socket-only";
      listen_on = "unix:@kitty";
    };
  };

  xdg.desktopEntries.nixi = {
    name = "nixi";
    exec = "kitty --session ${config.home.homeDirectory}/.config/kitty/dotfiles.session";
    terminal = false;
  };

  xdg.configFile."kitty/dotfiles.session".text = ''
    new_tab dotfiles
    layout splits
    launch --cwd ${config.home.homeDirectory}/.dotfiles claude
    launch --cwd ${config.home.homeDirectory}/.dotfiles --location=vsplit hx .
    launch --cwd ${config.home.homeDirectory}/.dotfiles --location=hsplit --var role=asenna
  '';

  programs.mpv.enable = true;

  programs.nnn.enable = true;

  programs.ripgrep.enable = true;

  programs.starship.enable = true;

  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  programs.zapzap.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    # `--cmd cd` reuses the `cd` name for zoxide: frecency jumps for short
    # names, normal cd semantics for absolute paths, `cd -`, `cd ..`, etc.
    options = [ "--cmd" "cd" ];
  };

  # Idle handling: blank the display after 5 min (matches the previous
  # powerdevilrc behaviour). No auto-lock — Super+L locks manually.
  services.hypridle = {
    enable = true;
    settings = {
      listener = [
        {
          # On lockscreen: blank display after 1 min of idle.
          # pidof check makes this a no-op during normal (unlocked) use.
          timeout = 60;
          on-timeout = "pidof hyprlock && hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          # Normal use: blank display after 5 min of idle.
          timeout = 300;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  # Wallpaper daemon. Monitor names match wayland.windowManager.hyprland.monitor
  # below: DP-2 is the Samsung Odyssey, HDMI-A-1 is the Dell U2412M. Both images
  # live inside the flake as Nix path literals so they get copied into the store
  # at eval time — no $HOME or absolute path leakage. The block form for
  # `wallpaper` is required by hyprpaper ≥0.8; the legacy `wallpaper = MON,PATH`
  # line is silently dropped by the new hyprlang special-category parser.
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      preload = [
        "${./assets/wallpaper_samsung.jpg}"
        "${./assets/wallpaper_dell.jpg}"
      ];
      wallpaper = [
        { monitor = "DP-2";      path = "${./assets/wallpaper_samsung.jpg}"; }
        { monitor = "HDMI-A-1";  path = "${./assets/wallpaper_dell.jpg}"; }
      ];
    };
  };

  # Hyprland compositor. systemd integration off — UWSM (enabled at the system
  # level via programs.hyprland.withUWSM) owns the hyprland-session.target, and
  # letting both manage it leads to dueling units.
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    configType = "hyprlang";
    settings = {
      # Dell U2412M sits physically to the left of the Samsung Odyssey.
      monitor = [
        "DP-2,3440x1440@119.96,0x0,1"
        "HDMI-A-1,1920x1200@59.95,-1920x0,1"
      ];

      input = {
        kb_file = "${umlautKeymap}";
        follow_mouse = 1;
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
      };

      decoration = {
        rounding = 4;
      };

      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        disable_scale_notification = true;
        # Explicitly disable the bundled "anime girl" default wallpaper. The
        # text baked into those PNGs (e.g. the "dt" easter egg) shows through
        # on any monitor not covered by hyprpaper; disable_hyprland_logo alone
        # doesn't always suppress it.
        force_default_wallpaper = 0;
      };

      bind = [
        # apps
        "SUPER, Return, exec, kitty"
        "SUPER, D, exec, fuzzel"
        "SUPER, L, exec, hyprlock"

        # window mgmt
        "SUPER, Q, killactive,"
        "SUPER, F, fullscreen,"
        "SUPER, V, togglefloating,"

        # focus (arrows — SUPER+L is taken by hyprlock above)
        "SUPER, left,  movefocus, l"
        "SUPER, down,  movefocus, d"
        "SUPER, up,    movefocus, u"
        "SUPER, right, movefocus, r"

        # move windows
        "SUPER SHIFT, left,  movewindow, l"
        "SUPER SHIFT, down,  movewindow, d"
        "SUPER SHIFT, up,    movewindow, u"
        "SUPER SHIFT, right, movewindow, r"

        # workspaces
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER, 6, workspace, 6"
        "SUPER, 7, workspace, 7"
        "SUPER, 8, workspace, 8"
        "SUPER, 9, workspace, 9"
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
        "SUPER SHIFT, 6, movetoworkspace, 6"
        "SUPER SHIFT, 7, movetoworkspace, 7"
        "SUPER SHIFT, 8, movetoworkspace, 8"
        "SUPER SHIFT, 9, movetoworkspace, 9"
      ];

      # Mouse-drag move/resize
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
