{ config, pkgs, ... }:
{
  home.username = "otso";
  home.homeDirectory = "/home/otso";
  home.stateVersion = "26.05";  # match your system stateVersion

  # user-level packages (as opposed to system-wide)
  home.packages = with pkgs; [
    ripgrep
    fd
  ];

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

  programs.firefox = {
    enable = true;
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      asenna = "sudo nixos-rebuild switch --flake ~/.dotfiles#markeeg";
    };
  };
}
