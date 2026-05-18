{ config, pkgs, peon-ping, ... }:
{
  imports = [ peon-ping.homeManagerModules.default ];
  home.username = "otso";
  home.homeDirectory = "/home/otso";
  home.stateVersion = "25.11";  # original install version — do not bump, independent of system.stateVersion

  # user-level packages (as opposed to system-wide)
  home.packages = with pkgs; [
    claude-code
    discord
    heroic
    mpv
    qbittorrent
  ];

  programs.peon-ping = {
    enable = true;
    package = peon-ping.packages.x86_64-linux.default;
    claudeCodeIntegration = true;
    settings = {
      default_pack = "peon";
      volume = 0.7;
      enabled = true;
      desktop_notifications = true;
    };
    installPacks = [ "peon" ];
  };

  programs.helix = {
    enable = true;
    settings.theme = "catppuccin_mocha";
  };

  programs.starship.enable = true;

  programs.kitty = {
    enable = true;
    settings = {
      font_family = "Comic Mono";
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
    };
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      asenna = "sudo nixos-rebuild switch --flake ~/.dotfiles#markeeg";
    };
    functions.fish_greeting = "";
  };

  # These files are force-written by home-manager. Any changes made in the KDE
  # System Settings GUI will be silently overwritten on the next `asenna`.
  xdg.configFile."ksmserverrc" = {
    force = true;
    text = ''
      [General]
      loginMode=emptySession
    '';
  };

  # Screen off after 5 min, no suspend, no auto-lock.
  xdg.configFile."powerdevilrc" = {
    force = true;
    text = ''
      [AC][Display and Brightness]
      DimDisplay=false
      TurnOffDisplay=true
      TurnOffDisplayIdleTimeoutSec=300

      [AC][Suspend and Power Button]
      AutoSuspendAction=0
    '';
  };

  xdg.configFile."kscreenlockerrc" = {
    force = true;
    text = ''
      [Daemon]
      Autolock=false
    '';
  };
}
