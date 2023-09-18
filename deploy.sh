#!/usr/bin/env sh

TEST_HOST=$TEST_HOST
SYSNAME="${1:-defaultname}"
TEST_ISO="$2"
PREFIX="aalbersh"
TEST_SYSTEM_XML="$PREFIX-$SYSNAME.xml"

function system_xml() {
	cp template.xml $TEST_SYSTEM_XML

	xmlstarlet edit --inplace \
		--update "/domain/name" \
		--value "$PREFIX-$SYSNAME" $TEST_SYSTEM_XML

	xmlstarlet edit --inplace \
		--update "/domain/title" \
		--value "Running xfstests" $TEST_SYSTEM_XML

	xmlstarlet edit --inplace \
		--update "/domain/devices/disk[@device='cdrom']/source/@file" \
		--value "/tmp/$PREFIX-$SYSNAME.iso" $TEST_SYSTEM_XML

	xmlstarlet edit --inplace \
		--update "/domain/devices/disk[@device='disk'][1]/source/@volume" \
		--value "$PREFIX-$SYSNAME-test" $TEST_SYSTEM_XML

	xmlstarlet edit --inplace \
		--update "/domain/devices/disk[@device='disk'][2]/source/@volume" \
		--value "$PREFIX-$SYSNAME-scratch" $TEST_SYSTEM_XML
}

function volume_xml() {
	name="$PREFIX-$SYSNAME-$1.xml"

	cp volume.xml $name

	xmlstarlet edit --inplace \
		--update "/volume/name" \
		--value "$PREFIX-$SYSNAME-$1" $name

	xmlstarlet edit --inplace \
		--update "/volume/target/path" \
		--value "/var/lib/libvirt/images/$PREFIX-$SYSNAME-$1.img" $name
}

if [[ -z "$TEST_HOST" ]]; then
    echo '$TEST_HOST is not defined' 1>&2
    exit 1
fi

# Cleaning
ssh -t $TEST_HOST "sudo rm -rf /tmp/$PREFIX-$SYSNAME.iso"
virsh --connect  qemu+ssh://$TEST_HOST/system vol-delete \
	--pool default \
	$PREFIX-$SYSNAME-test
virsh --connect  qemu+ssh://$TEST_HOST/system vol-delete \
	--pool default \
	$PREFIX-$SYSNAME-scratch

system_xml
volume_xml "test"
volume_xml "scratch"


rsync --compress --zc=lz4 -avz -P \
	$TEST_SYSTEM_XML \
	$TEST_HOST:/tmp/$SYSNAME.xml
rsync --compress --zc=lz4 -avz -P \
	$PREFIX-$SYSNAME-test.xml \
	$TEST_HOST:/tmp/$PREFIX-$SYSNAME-test.xml
rsync --compress --zc=lz4 -avz -P \
	$PREFIX-$SYSNAME-scratch.xml \
	$TEST_HOST:/tmp/$PREFIX-$SYSNAME-scratch.xml
rsync -avz -I -P \
	$TEST_ISO \
	$TEST_HOST:/tmp/$PREFIX-$SYSNAME.iso

ssh -t $TEST_HOST "sudo virsh vol-create --pool default /tmp/$PREFIX-$SYSNAME-test.xml"
ssh -t $TEST_HOST "sudo virsh vol-create --pool default /tmp/$PREFIX-$SYSNAME-scratch.xml"

set -e
ssh -t $TEST_HOST "sudo virsh create /tmp/$SYSNAME.xml"

rm -rf \
	$TEST_SYSTEM_XML \
	$PREFIX-$SYSNAME-test.xml \
	$PREFIX-$SYSNAME-scratch.xml
