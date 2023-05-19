#!/usr/bin/env bash

VALID_ARGS=$(getopt -o hk:m:t:c:q: --long help,kernel:,module:,totest:,config:,qemu-opts: -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1;
fi

LOCAL_CONFIG=".vmtest"
SHARE_DIR="/tmp/vmtest"
KERNEL=""
MODULE=""
TOTEST=""
TEST_CONFIG=""
QEMU_OPTS=""

function help() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTION...]

DESCRIPTION
    Run Virtual Machine to test linux kernel with fstests.

OPTIONS
    -k IMAGE, --kernel IMAGE
        Specify path to bzImage <IMAGE> to use instead of pre-build kernel. Note
        that this kernel should have features necessary to run in QEMU
    -m MODULE, --module MODULE
        Compiled module to load before systemd task is being run.
    -t OPTIONS, --totest OPTIONS
        fstests's command line options or shell script to run instead of fstests
    -c CONFIG, --test-config CONFIG
        fstests's configuration file
    -q OPTIONS, --qemu-opts OPTIONS
        Options to add to QEMU
    -h, --help
        Print this help and exit
CONFIG
    Instead of using all the command line OPTIONS above the config file can be
    created. The file should be located in current working directory and named
    '.vmtest'. For example:

    ➜  cat .vmtest
    KERNEL = "./arch/x86_64/boot/bzImage"
    MODULE = "./fs/xfs/xfs.ko"
    TOTEST = "-d -s xfs_1k_quota -s xfs_4k_quota -g verity"
    TEST_CONFIG = "./xfstests-config"
    QEMU_OPTS = "-hdc /dev/sdc4 -hdd /dev/sdc5 -serial mon:stdio"

    The variables are capitalized options.
EOF
}

function load_config() {
	shopt -s extglob
	while IFS='= ' read -r lhs rhs
	do
		if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
			rhs="${rhs%%\#*}"    # Del in line right comments
			rhs="${rhs%%*( )}"   # Del trailing spaces
			rhs="${rhs%\"*}"     # Del opening string quotes
			rhs="${rhs#\"*}"     # Del closing string quotes
			export $lhs="$rhs"
			echo "Option $lhs = '$rhs'"
		fi
	done < $1
}

function parse_args() {
	eval set -- "$VALID_ARGS"
	while [ : ]; do
		case "$1" in
			-k | --kernel)
				echo "Processing 'kernel' option: $2"
				KERNEL="$2"
				shift
				shift
				;;
			-m | --module)
				echo "Processing 'module' option: $2"
				MODULE="$2"
				shift
				shift
				;;
			-t | --totest)
				echo "Processing 'totest' option: $2"
				TOTEST="$2"
				shift
				shift
				;;
			-c | --test-config)
				echo "Processing 'test-config' option: $2"
				TEST_CONFIG="$2"
				shift
				shift
				;;
			-q | --qemu-opts)
				echo "Processing 'qemu-opts' option: $2"
				QEMU_OPTS="$2"
				shift
				shift
				;;
			-h | --help)
				help
				exit 0
				shift
				;;
			--) shift;
				break
				;;
		esac
	done
}

function init_share() {
	mkdir -p $SHARE_DIR

	if [ ! -w "$SHARE_DIR" ]; then
		echo "$SHARE_DIR is not writable"
		return
	fi
	mkdir -p $SHARE_DIR/modules
	mkdir -p $SHARE_DIR/results
}

function set_kernel() {
	if [[ -z "$1" ]]; then
		return;
	fi

	if [[ ! -f "$1" ]]; then
		echo "File $1 doesn't exist"
		return
	fi

	filename=$(basename $1)
	if [[ "$filename" != "vmlinux" && "$filename" != "bzImage" ]]; then
		echo "File $1 is not a kernel (vmlinuz or bzImage)"
	fi

	export NIXPKGS_QEMU_KERNEL_vm="$(realpath $1)"
	export QEMU_OPTS="$QEMU_OPTS"
	export NIX_DISK_IMAGE="$SHARE_DIR/vm.qcow2"
	echo "Kernel is set to $NIXPKGS_QEMU_KERNEL_vm"
}

function add_module() {
	if [[ -z "$1" ]]; then
		return;
	fi

	if [[ ! -f "$1" ]]; then
		echo "File $1 doesn't exist"
		return
	fi

	filename=$(basename $1)
	if [[ "$filename" != *.ko && "$filename" != *.o ]]; then
		echo "File $filename is not a module (.ko or .o)"
	fi

	echo "Module is set to $1"
	cp $1 "$SHARE_DIR/modules"
}

function set_totest() {
	if [[ -f "$1" ]]; then
		cp "$1" $SHARE_DIR/test.sh
		return
	fi

	echo "${1:--g verity}" > $SHARE_DIR/totest
	if [[ ! -f "$2" ]]; then
		cat << EOF > $SHARE_DIR/xfstests-config
export FSTYP="xfs"
export RESULT_BASE=/root/results

export TEST_DEV=/dev/sdb
export TEST_DIR=/mnt/test
export SCRATCH_DEV=/dev/sdc
export SCRATCH_MNT=/mnt/scratch
EOF
	else
		cp "$2" $SHARE_DIR/xfstests-config
	fi
}

if [[ -f "$LOCAL_CONFIG" ]]; then
	echo "Loading local config $LOCAL_CONFIG"
	load_config $LOCAL_CONFIG
fi

init_share
parse_args
set_kernel $KERNEL
add_module $MODULE
set_totest "$TOTEST" "$TEST_CONFIG"
