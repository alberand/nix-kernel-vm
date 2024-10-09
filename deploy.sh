#!/usr/bin/env sh

TEST_HOST=$TEST_HOST
SYSNAME="${1:-defaultname}"
TEST_ISO="$2"
PREFIX="aalbersh"
TEST_SYSTEM_XML="$PREFIX-$SYSNAME.xml"

if [[ -z "$TEST_HOST" ]]; then
    echo '$TEST_HOST is not defined' 1>&2
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "$(basename $0) <unique name> <path to iso>" 1>&2
    exit 0
fi

if ! virsh --connect qemu+ssh://$TEST_HOST/system version; then
    echo "Not able to connect to $TEST_HOST. Is your user in 'libvirt' group?"
    exit 1
fi

# Cleaning
ssh -t $TEST_HOST "sudo rm -rf /tmp/$PREFIX-$SYSNAME.iso"

virsh --connect  qemu+ssh://$TEST_HOST/system shutdown \
	$PREFIX-$SYSNAME
virsh --connect  qemu+ssh://$TEST_HOST/system undefine \
	$PREFIX-$SYSNAME
virsh --connect  qemu+ssh://$TEST_HOST/system vol-delete \
	--pool default \
	$PREFIX-$SYSNAME-test
virsh --connect  qemu+ssh://$TEST_HOST/system vol-delete \
	--pool default \
	$PREFIX-$SYSNAME-scratch

virsh --connect  qemu+ssh://$TEST_HOST/system \
	vol-create-as \
	--pool default \
	--name $PREFIX-$SYSNAME-test \
	--capacity 20G \
	--format qcow2

virsh --connect  qemu+ssh://$TEST_HOST/system \
	vol-clone \
	--pool default \
	$PREFIX-$SYSNAME-test \
	$PREFIX-$SYSNAME-scratch \

rsync -avz -I -P --ignore-existing \
       $TEST_ISO \
       $TEST_HOST:/tmp/$PREFIX-$SYSNAME.iso

virt-install --connect qemu+ssh://$TEST_HOST/system \
	--name "$PREFIX-$SYSNAME" \
	--hvm \
	--osinfo "nixos-unstable" \
	--memory=8000 \
	--vcpu 4 \
	--disk vol=default/$PREFIX-$SYSNAME-test,target.bus=sata \
	--disk vol=default/$PREFIX-$SYSNAME-scratch,target.bus=sata \
	--network network=default \
	--cdrom "/tmp/$PREFIX-$SYSNAME.iso" \
	--serial pty \
	--graphics none \
	--destroy-on-exit \
	--transient
