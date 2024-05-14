#!/usr/bin/env sh

set -e

dir=/tmp/xfstests

function cleanup() {
	if mountpoint -q $dir/test; then
		sudo -- umount $dir/test
	fi
	if mountpoint -q $dir/scratch; then
		sudo -- umount $dir/scratch
	fi
	losetup --detach /dev/loop0
	losetup --detach /dev/loop1
	rm -rf $dir
}

trap cleanup SIGTERM

if ! id -nG "$USER" | grep -qw "disk"; then
    echo "Sorry, your user '$USER' need to belong to group 'disk'"
fi

if test -d $dir; then
	echo "$dir exists. Recreating environment"
	cleanup
fi

mkdir -p $dir/{test,scratch}
xfs_io -f -c "falloc 0 2g" $dir/test.img
xfs_io -f -c "falloc 0 2g" $dir/scratch.img

mkfs.xfs -q -f -L test $dir/test.img
mkfs.xfs -q -f -L scratch $dir/scratch.img

if ! losetup --list | grep -q "loop0"; then
	losetup /dev/loop0 $dir/test.img
else
	echo "/dev/loop0 is already used"
	exit 1
fi
if ! losetup --list | grep -q "loop1"; then
	losetup /dev/loop1 $dir/scratch.img
else
	echo "/dev/loop1 is already used"
	exit 1
fi

sudo -- mount /dev/loop0 $dir/test
# sudo -- mount /dev/loop1 $dir/scratch

CONFIG=$(cat <<EOF
export FSTYP=xfs
export TEST_DEV=/dev/loop0
export TEST_DIR=$dir/test
export SCRATCH_DEV=/dev/loop1
export SCRATCH_MNT=$dir/scratch
EOF
)

if [ "$(basename `git rev-parse --show-toplevel`)" == "xfstests-dev" ]; then
	# echo to file
	echo "$CONFIG" > local.config
else
	echo ""
	echo "Put this in your local.config:"
	echo "$CONFIG"
fi
