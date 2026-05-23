# Graphical session: keyboard remap (keyd, below xkb), the Hyprland compositor
# launched under UWSM, xdg.portal wiring, and the greetd/tuigreet login.

{ pkgs, ... }:

{
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
      # Pin GlobalShortcuts explicitly; otherwise xdg-desktop-portal falls back
      # to the deprecated UseIn metadata key and logs a warning each session.
      "org.freedesktop.impl.portal.GlobalShortcuts" = [ "hyprland" ];
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
}
