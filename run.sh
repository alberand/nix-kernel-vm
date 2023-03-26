#!/usr/bin/env bash

VALID_ARGS=$(getopt -o k:m:t:c:q: --long kernel:,module:,totest:,config:,qemu-opts: -- "$@")
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
	echo "Kernel is set to $NIXPKGS_QEMU_KERNEL_vm"
}

function add_module() {
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
