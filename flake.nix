{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixos-generators,
  }:
    let
      system = "x86_64-linux";
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
        user-modules = [
          ({
            config,
            lib,
            ...
          }: {})
        ];
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

      devShells."old-kernel" =
        (lib.mkLinuxShell {
          inherit pkgs root;
          packages = [
            pkgs.gcc8
          ];
          no-vm = true;
        })
        .overrideAttrs (_final: prev: {
          nativeBuildInputs =
            nixpkgs.lib.lists.subtractLists
            [pkgs.clang pkgs.clang-tools]
            prev.nativeBuildInputs;
        });

      devShells."xfsprogs" = with pkgs;
        pkgs.mkShell {
          nativeBuildInputs = [
            icu
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
          buildInputs = [readline icu inih liburcu];
          shellHook = ''
            echo ""
            echo "Build with ccache:"
            echo -e '\tmake CC="ccache cc" -j$(nproc)'
            echo "Apply NixOS fix:"
            echo -e '\tnix-fix'
            echo ""
          '';
        };

      devShells."xfstests" = with pkgs; let
        xfstests-env = writeShellScriptBin "xfstests-env" (builtins.readFile ./xfstests-env.sh);
      in
        pkgs.mkShell {
          nativeBuildInputs = [
            autoconf
            automake
            libtool
          ];
          buildInputs = [
            acl
            attr
            gawk
            libaio
            libuuid
            libxfs
            openssl
            perl
            xfstests-env
          ];

          shellHook = ''
            export AWK=$(type -P awk)
            export ECHO=$(type -P echo)
            export LIBTOOL=$(type -P libtool)
            export MAKE=$(type -P make)
            export SED=$(type -P sed)
            export SORT=$(type -P sort)

            export PATH=${pkgs.lib.makeBinPath [acl attr bc e2fsprogs fio gawk keyutils
                                   libcap lvm2 perl procps killall quota
                                   util-linux which xfsprogs]}:$PATH
            ${xfstests-env}/bin/xfstests-env
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
          user-modules = [
            ({
              config,
              pkgs,
              lib,
              ...
            }: {
              programs.xfstests = {
                enable = true;
                src = builtins.fetchGit {
                  url = /home/alberand/Projects/xfstests-dev;
                  ref = "prj-quota-syscall";
                  rev = "f85dae4747350aba71e721acc437f3a1a910e8c7";
                  shallow = true;
                };
                testconfig = pkgs.fetchurl {
                  url = "https://gist.githubusercontent.com/alberand/85fa4d7e0929902ef5d303ae1de5cc8a/raw/f42bc75660efbf03ec6ee4f31e70d632735aeeec/xfstests-config";
                  hash = "sha256-dVNkh2FU1wSvPcIRAtFQryfQrKikyKMpbDCHHnvlMd0=";
                };
              };
              programs.xfsprogs = {
                enable = true;
                src = builtins.fetchGit {
                  url = /home/alberand/Projects/xfsprogs-dev;
                  ref = "prj-quota-syscall";
                  rev = "46045cfdc3a9bae4082daa2ba54ce8819f95a7da";
                  shallow = true;
                };
              };
            })
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
          version = "6.8.0-rc2";
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "linux";
            rev = "8eb99f6d07fa6e223f1d6035029088c7309cde05";
            sha256 = "zkMSIPthRauNYXSDBNb7WlTQ3c6Jdubb6HTOOrhU87E=";
          };
          structuredExtraConfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
            FS_VERITY_BUILTIN_SIGNATURES = yes;
            XFS_FS = yes;
          };
        };

        kernel = let
          version = "6.8.0-rc2";
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "linux";
            rev = "8eb99f6d07fa6e223f1d6035029088c7309cde05";
            sha256 = "zkMSIPthRauNYXSDBNb7WlTQ3c6Jdubb6HTOOrhU87E=";
          };
        in
          lib.buildKernel {
            inherit nixpkgs src version;
            modDirVersion = version;

            configfile = lib.buildKernelConfig {
              inherit nixpkgs pkgs src version;
              structuredExtraConfig = with pkgs.lib.kernel; {
                FS_VERITY = yes;
                FS_VERITY_BUILTIN_SIGNATURES = yes;
                XFS_FS = yes;
              };
            };
          };
      };

      apps.default = flake-utils.lib.mkApp {
        drv = packages.vmtest;
      };

      nixosConfigurations.xfstests-env = import ./xfstests-env.nix { inherit nixpkgs pkgs;};
    };
}
