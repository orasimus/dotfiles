{
  description = "My NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    peon-ping = {
      url = "github:PeonPing/peon-ping";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, peon-ping }: {
    nixosConfigurations.markeeg = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        # Pin the system's flake registry entry for `nixpkgs` to the same
        # input this configuration was built from, so ad-hoc commands like
        # `nix shell nixpkgs#foo` resolve against the locked revision instead
        # of whatever the default registry points at (typically stale).
        { nix.registry.nixpkgs.flake = nixpkgs; }
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit peon-ping; };
          home-manager.users.otso = import ./home.nix;
        }
      ];
    };
  };
}
