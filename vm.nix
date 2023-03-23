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
	testdisk = "/dev/sda";
	totest = "generic/572 generic/574 generic/575";

	# Custom local xfstests
	xfstests-overlay = (self: super: {
		xfstests = super.xfstests.overrideAttrs (super: {
			version = "git";
			src = /home/alberand/Projects/xfstests-dev;
			postInstall = super.postInstall + ''
			  cp ${./xfstests-config} $out/xfstests-config
			'';
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

	xfsprogs-overlay = (self: super: {
		xfsprogs = super.xfsprogs.overrideAttrs (prev: {
			version = "6.6.2";
			src = pkgs.fetchgit {
				url = /home/alberand/Projects/xfsprogs-dev;
				rev = "91bf9d98df8b50c56c9c297c0072a43b0ee02841";
				hash = "sha256-otEJr4PTXjX0AK3c5T6loLeX3X+BRBvCuDKyYcY9MQ4=";
			};
			buildInputs = with pkgs; [ gnum4 readline icu inih liburcu ];
		});
	});

	xfsprogs-overlay-remote = (self: super: {
		xfsprogs = super.xfsprogs.overrideAttrs (prev: {
			version = "6.6.2";
			src = pkgs.fetchFromGitHub {
				owner = "alberand";
				repo = "xfsprogs";
				rev = "fdec21e";
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
		configfile = /home/alberand/Projects/xfs-verity-v2/.config;
		src = fetchGit /home/alberand/Projects/xfs-verity-v2;
	};

	kernel-headers-overlay = (self: super: {
		linuxHeaders = super.linuxHeaders.overrideAttrs (prev: {
			version = "6.2.0-rc2";
			src = fetchGit /home/alberand/Projects/xfs-verity-v2;
		});
	});

in
{
        imports = [
		(modulesPath + "/profiles/qemu-guest.nix")
		(modulesPath + "/virtualisation/qemu-vm.nix")
        ];

	boot = {
		kernelParams = ["console=ttyS0,115200n8" "console=ttyS0"];
		consoleLogLevel = lib.mkDefault 7;
		# This is happens before systemd
		postBootCommands = "echo 'Not much to do before systemd :)' > /dev/kmsg";
		crashDump.enable = true;

		# Set my custom kernel
		# kernelPackages = kernel-custom;
		kernelPackages = pkgs.linuxPackages_latest;
	};

	# Auto-login with empty password
	users.extraUsers.root.initialHashedPassword = "";
	services.getty.autologinUser = lib.mkDefault "root";

	networking.firewall.enable = false;
	networking.hostName = "vm";
	networking.useDHCP = false;
	services.getty.helpLine = ''
		Log in as "root" with an empty password.
		If you are connect via serial console:
		Type CTRL-A X to exit QEMU
	'';

	# Not needed in VM
	documentation.doc.enable = false;
	documentation.man.enable = false;
	documentation.nixos.enable = false;
	documentation.info.enable = false;
	programs.bash.enableCompletion = false;
	programs.command-not-found.enable = false;

	systemd.tmpfiles.rules = [
		"d /mnt 1777 root root"
		"d /mnt/test 1777 root root"
		"d /mnt/scratch 1777 root root"
	];
	# Do something after systemd started
	systemd.services."serial-getty@ttyS0".enable = true;
	systemd.services.xfstests = {
		enable = true;
		serviceConfig = {
			Type = "oneshot";
			StandardOutput = "tty";
			StandardError = "tty";
			User = "root";
			Group = "root";
                        WorkingDirectory = "/root";
		};
		after = [ "network.target" "network-online.target" "local-fs.target" ];
		wants = [ "network.target" "network-online.target" "local-fs.target" ];
		wantedBy = [ "multi-user.target" ];
                # postStop = "${pkgs.systemd}/bin/systemctl poweroff";
                postStop = "${pkgs.kmod}/bin/rmmod xfs";
		script = ''
			${pkgs.kmod}/bin/insmod /root/modules/xfs.ko
			source ${pkgs.xfstests}/xfstests-config
			${pkgs.bash}/bin/bash -lc "${pkgs.xfstests}/bin/xfstests-check -d ${totest}"
		'';
	};

	# Setup envirionment
        #environment.variables.TERM = "xterm";
        #environment.variables.TEST_DEV = "/dev/sdb";
        #environment.variables.TEST_DIR = "/mnt/test";
        #environment.variables.SCRATCH_DEV = "/dev/sdc";
        ##environment.variables.SCRATCH_MNT = "/mnt/scratch";

	networking.interfaces.eth1 = {
		ipv4.addresses = [{
			address = "11.11.11.12";
			prefixLength = 32;
		}];
	};

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
			networkingOptions = [
				"-device e1000,netdev=network0,mac=00:00:00:00:00:00"
				"-netdev tap,id=network0,ifname=tap0,script=no,downscript=no"
			];
			options = [
				# I want to try a kernel which I compiled somewhere
				#"-kernel /home/user/my-linux/arch/x86/boot/bzImage"
				#"-kernel /home/alberand/my-linux/arch/x86/boot/bzImage"
				# OR
				# You can set env. variable not to change configuration everytime:
				#   export NIXPKGS_QEMU_KERNEL_fstests_vm=/path/to/arch/x86/boot/bzImage
				# The name is NIXPKGS_QEMU_KERNEL_<networking.hostName>

				# Append real partitions to VM
				"-hdc ${testdisk}4"
				"-hdd ${testdisk}5"
				"-usb -device usb-host,hostbus=2,hostport=4"
				#"-usb -device usb-host,vendorid=0x8564,productid=0x1000"
				"-serial mon:stdio"
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
			results = {
				source = "/home/alberand/Projects/vm/results";
				target = "/root/results";
			};
		};
	};

	# Add packages to VM
	environment.systemPackages = with pkgs; [
		htop
		util-linux
		xfstests
		tmux
		fsverity-utils
		trace-cmd
		perf-tools
		linuxPackages_latest.perf
		openssl
		xfsprogs
		usbutils
		bpftrace
                xxd
                xterm
                zsh
	];

	programs.zsh = {
		enable = true;
		ohMyZsh = {
			enable = true;
                        # plugins = [ "git" ];
			theme = "robbyrussell";
		};
		interactiveShellInit = ''
			function precmd {
				eval `resize`
			}
		'';
	};

	# Apply overlay on the package (use different src as we replaced 'src = ')
	nixpkgs.overlays = [ 
		xfstests-overlay
		xfsprogs-overlay
	];

	users.users.root = {
		shell = pkgs.zsh;
        };
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
