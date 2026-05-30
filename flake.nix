{
  description = "My NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-community/impermanence — bind-mount declared paths from /persist
    # back into place on each boot. Its own flake pulls nixpkgs + home-manager
    # only for its dev shell / examples; follows = "" drops those from our lock.
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "";
      inputs.home-manager.follows = "";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, impermanence, sops-nix }: {
    nixosConfigurations.markeeg = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        impermanence.nixosModules.impermanence
        sops-nix.nixosModules.sops
        # Pin the system's flake registry entry for `nixpkgs` to the same
        # input this configuration was built from, so ad-hoc commands like
        # `nix shell nixpkgs#foo` resolve against the locked revision instead
        # of whatever the default registry points at (typically stale).
        { nix.registry.nixpkgs.flake = nixpkgs; }
        home-manager.nixosModules.home-manager
        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # On activation, delete any pre-existing unmanaged file at a path HM
          # wants to own. The previous backupFileExtension = "hm-backup"
          # approach broke under impermanence: persisted dirs like
          # ~/.config/discord replayed both the app's settings.json and an old
          # .hm-backup on every boot, so the next activation's `mv settings.json
          # settings.json.hm-backup` refused to clobber and aborted the whole
          # unit — taking every HM symlink (hyprland.conf, btop, fuzzel, …)
          # down with it. `rm -f` only fires on real files that differ from
          # HM's intended content (identical files are skipped quietly), so
          # this only ever discards content HM was about to overwrite anyway.
          home-manager.backupCommand = "${pkgs.coreutils}/bin/rm -f";
          # impermanence's NixOS module (already in modules above) auto-imports
          # the home-manager-side bits into every HM user when home-manager is
          # used as a NixOS module, so `home.persistence` becomes available
          # inside home.nix without any sharedModules wiring here.
          home-manager.users.otso = import ./home.nix;
        })
      ];
    };
  };
}
