{
  description = "A very basic flake";

  outputs = { self, nixpkgs }: {

    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ 
        ./vm.nix {
	  environment.variables.EDITOR = "neovim";
          environment.systemPackages = [
            nixpkgs.legacyPackages.x86_64-linux.vim
          ];
	users.users.hahahahaha = {
		isNormalUser  = true;
		description  = "Test user";
	};

        }
		"${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
		"${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"

      ];
    };

    #overlays.default = (final: prev: {
    #});

    packages.x86_64-linux.default = 
      self.nixosConfigurations.vm.config.system.build.vm;
  };
}
