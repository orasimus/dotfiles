{ config, pkgs, peon-ping, ... }:
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
  imports = [ peon-ping.homeManagerModules.default ];
  home.username = "otso";
  home.homeDirectory = "/home/otso";
  home.stateVersion = "25.11";  # original install version — do not bump, independent of system.stateVersion

  # user-level packages (as opposed to system-wide)
  home.packages = with pkgs; [
    claude-code
    discord
    fuzzel
    heroic
    mpv
    sublime-merge
    qbittorrent
    zapzap
  ];

  programs.peon-ping = {
    enable = true;
    package = peon-ping.packages.x86_64-linux.default;
    claudeCodeIntegration = true;
    settings = {
      default_pack = "peon";
      volume = 0.7;
      enabled = true;
      # No desktop-notification daemon is running on this host (Hyprland is
      # bar-less and notification-less by design), so the popup channel would
      # silently drop. Audio still fires.
      desktop_notifications = false;
    };
    installPacks = [ "peon" ];
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "catppuccin_mocha";
      editor.soft-wrap.enable = true;
    };
  };

  programs.starship.enable = true;

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
    settings = {
      font_family = "Comic Mono";
      confirm_os_window_close = 0;
      allow_remote_control = "yes";
      background            = "#1e1e2e";
      foreground            = "#cdd6f4";
      selection_background  = "#cba6f7";
      selection_foreground  = "#1e1e2e";
      url_color             = "#89b4fa";
      cursor                = "#f5e0dc";
      cursor_text_color     = "#1e1e2e";
      active_tab_background   = "#cba6f7";
      active_tab_foreground   = "#1e1e2e";
      inactive_tab_background = "#313244";
      inactive_tab_foreground = "#cdd6f4";
      tab_bar_background      = "#181825";
      color0  = "#45475a";
      color8  = "#585b70";
      color1  = "#f38ba8";
      color9  = "#f38ba8";
      color2  = "#a6e3a1";
      color10 = "#a6e3a1";
      color3  = "#f9e2af";
      color11 = "#f9e2af";
      color4  = "#89b4fa";
      color12 = "#89b4fa";
      color5  = "#cba6f7";
      color13 = "#cba6f7";
      color6  = "#94e2d5";
      color14 = "#94e2d5";
      color7  = "#bac2de";
      color15 = "#a6adc8";
    };
  };

  # example: configure git properly
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

  programs.fish = {
    enable = true;
    shellAliases = {
      asenna = "sudo nixos-rebuild switch --flake ~/.dotfiles#markeeg";
    };
    functions.fish_greeting = "";
  };

  xdg.desktopEntries.nixi = {
    name = "nixi";
    exec = "kitty --session ${config.home.homeDirectory}/.config/kitty/dotfiles.session";
    terminal = false;
  };

  xdg.configFile."kitty/dotfiles.session".text = ''
    new_tab dotfiles
    layout splits
    launch --cwd /home/otso/.dotfiles claude
    launch --cwd /home/otso/.dotfiles --location=vsplit hx .
    launch --cwd /home/otso/.dotfiles --location=hsplit --var role=asenna
  '';

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

  # Idle handling: blank the display after 5 min (matches the previous
  # powerdevilrc behaviour). No auto-lock — Super+L locks manually.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
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
}
