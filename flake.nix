{
	description = "A very basic flake";

	inputs = {
		flake-utils.url = "github:numtide/flake-utils";
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs, flake-utils }:
	flake-utils.lib.eachDefaultSystem (system: let
		pkgs = nixpkgs.legacyPackages.${system};
	in {

		nixosConfigurations = {
			generic = nixpkgs.lib.nixosSystem {
				inherit system;
				modules = [
					./vm.nix {
						environment.variables.EDITOR = "neovim";
						environment.systemPackages = [
							pkgs.vim
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
		};

		packages.vmtest = pkgs.symlinkJoin {
			name = "vmtest";
			paths = with self.nixosConfigurations.generic.config.system.build; [
				vm
				kernel
			];
			preferLocalBuild = true;
		};

		apps = {
			default = flake-utils.lib.mkApp {
				drv = self.packages.${system}.vmtest.config.system.build.vm;
			};
		};

		#packages.vmtest =
			#self.nixosConfigurations.vm.config.system.build.vm;
		packages = rec {
			default = self.packages."${system}".vmtest;
		};
	});
}
