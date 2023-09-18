#!/usr/bin/env sh

TEST_HOST=$TEST_HOST
SYSNAME="${1:-defaultname}"
TEST_ISO="$2"
PREFIX="aalbersh"
TEST_SYSTEM_XML="$PREFIX-$SYSNAME.xml"

cat << EOF > $TEST_SYSTEM_XML
<domain type='kvm'>
  <name>name</name>
  <title>Short description</title>
  <memory unit='KiB'>33554432</memory>
  <currentMemory unit='KiB'>33554432</currentMemory>
  <vcpu placement='static'>8</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-rhel9.0.0'>hvm</type>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='8' dies='1' cores='1' threads='1'/>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>

    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/tmp/nixos-new.iso'/>
      <target dev='sda' bus='sata'/>
      <boot order='1'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>

    <disk type='volume' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source pool='default' volume='test'/>
      <target dev='vdb' bus='virtio'/>
    </disk>

    <disk type='volume' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source pool='default' volume='scratch'/>
      <target dev='vdc' bus='virtio'/>
    </disk>

    <!--
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='/var/lib/libvirt/images/aalbersh-fstests.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <boot order='2'/>
      <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
    </disk>
    -->

    <interface type='bridge'>
      <mac address='52:54:00:bf:64:52'/>
      <source bridge='bridge0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='tablet' bus='usb'>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <audio id='1' type='none'/>
    <video>
      <model type='vga' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0'/>
    </memballoon>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </rng>
  </devices>
</domain>
EOF

cat << EOF > volume.xml
<volume>
	<name>name</name>
	<allocation unit="G">20</allocation>
	<capacity unit="G">20</capacity>
	<target>
		<path>/var/lib/virt/images/sparse.img</path>
		<format type='qcow2'/>
	</target>
</volume>
EOF

function system_xml() {
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

if [ "$#" -ne 2 ]; then
    echo "$(basename $0) <unique name> <path to iso>" 1>&2
    exit 0
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
	volume.xml \
	$TEST_SYSTEM_XML \
	$PREFIX-$SYSNAME-test.xml \
	$PREFIX-$SYSNAME-scratch.xml
