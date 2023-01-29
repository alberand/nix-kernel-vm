# Create two disks:
#   xfs_io -f -c "falloc 0 13g" {test,scratch}.img
# Build VM with:
#   nix-build '<nixpkgs/nixos>' -A vm --arg configuration ./vm.nix
# Exiting VM
#   Use 'poweroff' command instead of CTRL-A X. Using the latter could lead to
#   corrupted root image and your VM won't boot (not always). However, it is
#   easily fixable by removing the image and running the VM again. The root
#   image is qcow2 file generated during the first run of your VM.
# Kernel Config:
#   Note that your kernel must have some features enabled. The list of features
#   could be found here https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix#L1142
{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  # fstests confgiuration
  fstyp = "xfs";

  # Custom local xfstests
  xfstests-overlay = (self: super: {
    xfstests = super.xfstests.overrideAttrs (prev: {
      version = "git";
      src = /home/alberand/Projects/xfstests-dev;
    });
  });

  progs = with pkgs; import ./progs.nix { 
    inherit lib stdenv buildPackages fetchurl autoconf automake gettext
      libtool pkg-config icu libuuid readline inih liburcu  nixosTests;
  };


  xfsprogs-overlay = (self: super: {
    xfsprogs = super.xfsprogs.overrideAttrs (prev: {
      version = "6.6.2";
      #src = /home/alberand/Projects/xfsprogs-dev;
      src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfsprogs";
        rev = "eb4d8447361bcf31ef1caad0cd9548b2c5536305";
        sha256 = "1qb65XmkLw7YNVLhSLsafZUhjTdJPpnFNVbg2uibqYQ=";
      };
      buildInputs = with pkgs; [ gnum4 readline icu inih liburcu ];
    });
  });

  # Custom remote xfstests
  xfstests-overlay-remote = (self: super: {
    xfstests = super.xfstests.overrideAttrs (prev: {
      version = "git";
      src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfstests";
        rev = "6e6fb1c6cc619afb790678f9530ff5c06bb8f24c";
        sha256 = "OjkO7wTqToY1/U8GX92szSe7mAIL+61NoZoBiU/pjPE=";
      };
    });
  });

  kernel-custom = pkgs.linuxKernel.customPackage { 
    # Note that nix uses this version to install relevant tools (e.g. flex).
    # You can specify 'git' not to change it every time you change the verions
    # but I haven't got it working properly. Nix will tell you which version
    # you should specify if you don't know.
    version = "6.2.0-rc2";
    configfile = /home/alberand/Projects/vm/.config;
    src = /home/alberand/Projects/xfs-verity-v2-empty;
  };

  kernel-custom-config = let
      linux-custom-pkg = { fetchFromGitHub, buildLinux, ... } @ args:
        buildLinux (args // rec {
          version = "6.1.0-rc4";
          configfile = "/home/alberand/Projects/vm/.config";

          #src = fetchurl {
          #  url = "https://github.com/alberand/linux/tarball/pp-test";
          #  sha256 = "BzfNAS3qzgPdk31oOkek038Co70BkdAlXJBhp6fL/g0=";
          #};

          #src = fetchFromGitHub {
          #  owner = "alberand";
          #  repo = "linux";
          #  rev = "3249a04140b3b1e4f4d342ca5f8f561724b7fa1e";
          #  sha256 = "lI52Z9BL1A+UDmaPmWuXA+iqQEz0mPPjQhBfGsDbHoY=";
          #};
          src = /home/alberand/Projects/xfs-verity-v2-empty;

          extraConfig = ''
            FS_VERITY y
            X86_AMD_PSTATE n

            DEBUG_KERNEL y
            KGDB y
            KGDB_SERIAL_CONSOLE y
            DEBUG_INFO y
          '';

          extraMeta.branch = "xfs-verity-v2-empty";
        });
      linux-custom-fn = pkgs.callPackage linux-custom-pkg { };
     in 
      pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux-custom-fn);

in
{
  imports = [ 
    (modulesPath + "/profiles/qemu-guest.nix") 
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  boot.kernelParams = ["console=ttyS0,115200n8" "console=ttyS0"];
  boot.consoleLogLevel = lib.mkDefault 7;
  boot.initrd.kernelModules = [ "" ];
  boot.growPartition = false;
  # This is happens before systemd
  boot.postBootCommands = "echo 'Not much to do before systemd :)' > /dev/kmsg";

  # Set my custom kernel
  # boot.kernelPackages = kernel-cache;
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linuxKernel.kernels.kernel-cache;

  nixpkgs.localSystem.system = "x86_64-linux";

  console.enable = true;
  systemd.services."serial-getty@ttyS0".enable = true;

  networking.firewall.enable = false;
  networking.hostName = "fstests-vm";
  networking.useDHCP = false;
  services.getty.helpLine = ''
    Log in as "root" with an empty password.
    If you are connect via serial console:
    Type Ctrl-a c to switch to the qemu console
    and `quit` to stop the VM.
  '';

  # Auto-login with empty password
  users.extraUsers.root.initialHashedPassword = "";
  services.getty.autologinUser = lib.mkDefault "root";

  # Not needed in VM
  documentation.doc.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  documentation.info.enable = false;
  programs.bash.enableCompletion = false;
  programs.command-not-found.enable = false;

  # Do something after systemd started
  systemd.services.foo = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      echo 'This service runs right near login' > /dev/kmsg
    '';
  };

  # Setup envirionment
  environment.variables.TEST_DEV = "/dev/sdb";
  environment.variables.TEST_DIR = "/mnt/test";
  environment.variables.SCRATCH_DEV = "/dev/sdc";
  environment.variables.SCRATCH_MNT = "/mnt/scratch";

  virtualisation = {
      diskSize = 20000; # MB
      memorySize = 4096; # MB
      cores = 4;
      writableStoreUseTmpfs = false;
      useDefaultFilesystems = true;
      # Run qemu in the terminal not in Qemu GUI
      graphics = false;
      #emptyDiskImages = [ 8192 4096 ]; # Create 2 virtual disk with 8G and 4G

      qemu = {
        options = [
          # I want to try a kernel which I compiled somewhere
          #"-kernel /home/user/my-linux/arch/x86/boot/bzImage"
	  #"-kernel /home/alberand/my-linux/arch/x86/boot/bzImage"
	  # OR
	  # You can set env. variable not to change configuration everytime:
	  #   export NIXPKGS_QEMU_KERNEL_fstests_vm=/path/to/arch/x86/boot/bzImage
	  # The name is NIXPKGS_QEMU_KERNEL_<networking.hostName>

          # Append real partitions to VM
          "-hdc /dev/sda4"
          "-hdd /dev/sda5"
        ];
        # Append images as partition to VM
        drives = [
          #{ name = "vdc"; file = "${toString ./test.img}"; }
          #{ name = "vdb"; file = "${toString ./scratch.img}"; }
        ];
      };

      sharedDirectories = {
        fstests = { 
          source = "/home/alberand/Projects/xfstests-dev";
          target = "/root/xfstests"; 
        };
        modules = { 
          source = "/home/alberand/Projects/vm/modules";
          target = "/root/modules"; 
        };
      };
  };

  # Add packages to VM
  environment.systemPackages = with pkgs; [
	htop
        util-linux
        xfstests
        vim
        tmux
        fsverity-utils
        trace-cmd
	perf-tools
	linuxPackages_latest.perf
	openssl
        progs
  ];


  # Apply overlay on the package (use different src as we replaced 'src = ')
  nixpkgs.overlays = [ 
	xfstests-overlay
	(self: super: let
		pkgs = self;
	in {
		linuxKernel = super.linuxKernel // {
			kernels = super.linuxKernel.kernels.extend (kself: ksuper: {
				kernel-cache = self.linuxPackages_latest.kernel.override ({
					argsOverride = {
						version = "6.2.0-rc2";
						modDirVersion = "6.2.0-rc2";
						src = /home/alberand/Projects/xfs-verity-v2-empty;
						# configfile = pkgs.linuxConfig { 
							#src = /home/alberand/Projects/vm/.config; 
						#};
						separateDebugInfo = true;
						preConfigure = lib.optionalString config.programs.ccache.enable ''
						export CCACHE_DIR=${config.programs.ccache.dir}
						export CCACHE_UMASK=007
						export NIX_CFLAGS_COMPILE="$(echo "$NIX_CFLAGS_COMPILE" | sed -e "s/-frandom-seed=[^-]*//")"
						'';
          extraConfig = ''
            FS_VERITY y
            X86_AMD_PSTATE n

            DEBUG_KERNEL y
            KGDB y
            KGDB_SERIAL_CONSOLE y
            DEBUG_INFO y
          '';
	  ignoreConfigErrors = true;
					};
					stdenv = pkgs.ccacheStdenv;
					buildPackages = pkgs.buildPackages // {
						stdenv = pkgs.ccacheStdenv;
					};
				});
			});
		};
	})

	(self: super: {
		ccacheWrapper = super.ccacheWrapper.override {
			extraConfig = ''
			export CCACHE_COMPRESS=1
			export CCACHE_DIR=/var/cache/ccache
			export CCACHE_UMASK=007
			'';
		};
	})
  ];

  # xfstests related
  users.users.fsgqa = {
	isNormalUser  = true;
	description  = "Test user";
  };

  users.users.fsgqa2 = {
	isNormalUser  = true;
	description  = "Test user";
  };

  users.users.fsgqa-123456 = {
	isNormalUser  = true;
	description  = "Test user";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
