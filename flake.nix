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
  };

  outputs = { self, nixpkgs, home-manager, impermanence }: {
    nixosConfigurations.markeeg = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        impermanence.nixosModules.impermanence
        # Pin the system's flake registry entry for `nixpkgs` to the same
        # input this configuration was built from, so ad-hoc commands like
        # `nix shell nixpkgs#foo` resolve against the locked revision instead
        # of whatever the default registry points at (typically stale).
        { nix.registry.nixpkgs.flake = nixpkgs; }
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # On activation, rename any pre-existing unmanaged file at a path HM
          # wants to own to <name>.hm-backup instead of failing the unit. Lets
          # us migrate live app configs into programs.* without manual cleanup.
          home-manager.backupFileExtension = "hm-backup";
          # impermanence's NixOS module (already in modules above) auto-imports
          # the home-manager-side bits into every HM user when home-manager is
          # used as a NixOS module, so `home.persistence` becomes available
          # inside home.nix without any sharedModules wiring here.
          home-manager.users.otso = import ./home.nix;
        }
      ];
    };
  };
}
