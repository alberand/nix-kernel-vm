{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    fetch-lore.url = "github:dramforever/fetch-lore";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, fetch-lore, nixos-generators }:
  flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
  let
    pkgs = import nixpkgs {
      inherit system;
    };
    # default kernel if no custom kernel were specified
    root = builtins.toString ./.;
  in rec {
    lib = import ./lib.nix {
      inherit pkgs nixos-generators;
    };

    devShells.default = lib.mkLinuxShell {
      inherit pkgs root;
    };

    devShells."light" = lib.mkLinuxShell {
      inherit pkgs root;
      packages = [
        (lib.deploy {
          inherit pkgs;
        })
      ];
      no-vm = true;
    };

    devShells."old-kernel" = (lib.mkLinuxShell {
      inherit pkgs root;
      packages = [
        pkgs.gcc8
      ];
      no-vm = true;
    }).overrideAttrs (final: prev: {
      nativeBuildInputs = nixpkgs.lib.lists.subtractLists
        [ pkgs.clang pkgs.clang-tools] prev.nativeBuildInputs;
    });

    devShells."xfsprogs" = with pkgs; pkgs.mkShell {
      nativeBuildInputs = [
        gettext
        pkg-config
        libuuid # codegen tool uses libuuid
        liburcu # required by crc32selftest
        libtool
        autoconf
        automake
        (pkgs.writeScriptBin "nix-fix" ''
          #!${pkgs.stdenv.shell}
          git am -3 ${./0001-xfsprogs-force-copy-install-sh-to-always-overwrite.patch}
        '')
      ];
      buildInputs = [ readline icu inih liburcu ];
      shellHook = ''
        echo ""
        echo "Build with ccache:"
        echo -e '\tmake CC="ccache cc" -j$(nproc)'
        echo "Apply NixOS fix:"
        echo -e '\tnix-fix'
        echo ""
      '';
    };

    devShells."xfstests" = with pkgs; pkgs.mkShell {
      nativeBuildInputs = [
        autoconf automake libtool
      ];
      buildInputs = [
        acl attr gawk libaio libuuid libxfs openssl perl
      ];

      shellHook = ''
          export AWK=$(type -P awk)
          export ECHO=$(type -P echo)
          export LIBTOOL=$(type -P libtool)
          export MAKE=$(type -P make)
          export SED=$(type -P sed)
          export SORT=$(type -P sort)
      '';
    };


    # Config file derivation
    packages = rec {
      default = vmtest;

      vmtest = lib.mkVmTest {
        inherit pkgs;
        qemu-options = [
          "-hda /dev/loop0"
          "-hdb /dev/loop1"
        ];
      };

      iso = lib.mkIso {
        inherit pkgs;
      };

      deploy = lib.deploy {
        inherit pkgs;
      };

      kernel-config = lib.buildKernelConfig {
        inherit nixpkgs pkgs;
        defconfig = "allnoconfig";
        structuredExtraConfig = with pkgs.lib.kernel; {
          FS_VERITY = yes;
          XFS_FS = yes;
        };
      };

      kernel = lib.buildKernel {
        inherit pkgs;
        version = "6.8.0-rc4";
        src = pkgs.fetchFromGithub {
          owner = "alberand";
          repo = "linux";
          rev = "8eb99f6d07fa6e223f1d6035029088c7309cde05";
          sha256 = "";
        };
        configfile = lib.buildKernelConfig {
          inherit nixpkgs pkgs;
          defconfig = "allnoconfig";
          structuredExtraConfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
            XFS_FS = yes;
          };
        };
      };
    };

    apps.default = flake-utils.lib.mkApp {
      drv = packages.vmtest;
    };
  });
}
