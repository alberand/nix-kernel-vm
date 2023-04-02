{
	description = "A very basic flake";

	inputs = {
		#flake-utils.url = "github:numtide/flake-utils";
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
		xfsprogs = {
			type = "github";
			owner = "alberand";
			repo = "xfsprogs";
			flake = false;
		};
	};

	outputs = { self, nixpkgs, xfsprogs, ... }:
	let
		system = "x86_64-linux";
		pkgs = nixpkgs.legacyPackages.${system};
	in {

		nixosConfigurations = {
			"generic" = nixpkgs.lib.nixosSystem {
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

		packages."${system}" ={
			default = self.packages."${system}".vmtest;

			vmtest = pkgs.writeScriptBin "vmtest"
				((builtins.readFile ./run.sh) + ''
					${self.packages."${system}".vm}/bin/run-vm-vm
					echo "View results at $SHARE_DIR/results"
				'');

			vm = pkgs.symlinkJoin {
				name = "vm";
				paths = with self.nixosConfigurations.generic.config.system.build; [
					vm
					kernel
				];
				preferLocalBuild = true;
			};
		};

		apps."${system}".default = {
				type = "app";
				program = "${self.packages.${system}.vmtest}/bin/vmtest";
		};

		devShells."${system}".default = with pkgs;
			mkShell {
				nativeBuildInputs = [
					ctags
					getopt
					flex
					bison
					perl
					gnumake
					bc
					pkg-config
					clang
					clang-tools
					# gcc
					# binutils
					file
					gettext
					libtool
					qemu_full
					qemu-utils
					automake
					autoconf

					# xfstests
					e2fsprogs
					attr
					acl
					libaio
					keyutils
					fsverity-utils
					ima-evm-utils
					util-linux
					stress-ng
					dbench
					xfsprogs
					fio
					linuxquota
					nvme-cli
				];

				buildInputs = [
					elfutils
					ncurses
					openssl
					zlib
				];
				# This is needed to disable unwanted gcc flags (such as
				# -Werror=format-security, this breaks buildroot builds)
				hardeningDisable = [ "all" ];
			};
	};
}
