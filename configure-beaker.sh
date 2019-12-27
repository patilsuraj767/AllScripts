#!/bin/bash 

configure_bridge () {

echo "================= Setting Up Bridge network on $interface_name ==================="

cp /etc/sysconfig/network-scripts/ifcfg-"$interface_name" /var/tmp/
rm -rf /etc/sysconfig/network-scripts/ifcfg-"$interface_name"

cat > /etc/sysconfig/network-scripts/ifcfg-br0 << ENDOFFILE
DEVICE=br0
TYPE=Bridge
ONBOOT=yes
BOOTPROTO=dhcp
DELAY=0
ENDOFFILE

cat > /etc/sysconfig/network-scripts/ifcfg-"$interface_name" << ENDOFFILE
DEVICE="$interface_name"
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
NETBOOT=yes
BRIDGE=br0
ENDOFFILE

sleep 5

nmcli connection reload


}

create_virsh_network () {

echo "================= Setting Up isolated network ==================="

cat > ~/isolated.xml << ENDOFFILE
<network>
  <name>isolated</name>
  <uuid>2bc4960a-33e1-452a-a886-e6215007862b</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <mac address='52:54:00:d0:a1:49'/>
  <domain name='isolated'/>
  <ip address='192.168.123.1' netmask='255.255.255.0'>
  </ip>
</network>
ENDOFFILE

virsh net-define isolated.xml
virsh net-autostart isolated
virsh net-start isolated
rm -rf ~/isolated.xml

}

create_virsh_pool () {

echo "================= Creating vms pool ==================="

mkdir /home/vms
cat > ~/vmpool.xml << ENDOFFILE
<pool type='dir'>
  <name>vms</name>
  <uuid>770b7133-975e-4a81-9463-f3deb3914df6</uuid>
  <capacity unit='bytes'>227782037504</capacity>
  <allocation unit='bytes'>33832960</allocation>
  <available unit='bytes'>227748204544</available>
  <source>
  </source>
  <target>
    <path>/home/vms</path>
    <permissions>
      <mode>0755</mode>
      <owner>0</owner>
      <group>0</group>
      <label>unconfined_u:object_r:home_root_t:s0</label>
    </permissions>
  </target>
</pool>
ENDOFFILE

virsh pool-define vmpool.xml
virsh pool-start vms
virsh pool-autostart vms

rm -rf ~/vmpool.xml

echo "================= Creating iso pool ==================="

mkdir /home/iso
cat > ~/isopool.xml << ENDOFFILE
<pool type='dir'>
  <name>isos</name>
  <uuid>c24564d2-fc91-41f8-974a-de92a41623bb</uuid>
  <capacity unit='bytes'>227782037504</capacity>
  <allocation unit='bytes'>33832960</allocation>
  <available unit='bytes'>227748204544</available>
  <source>
  </source>
  <target>
    <path>/home/iso</path>
    <permissions>
      <mode>0755</mode>
      <owner>0</owner>
      <group>0</group>
      <label>unconfined_u:object_r:home_root_t:s0</label>
    </permissions>
  </target>
</pool>
ENDOFFILE

virsh pool-define isopool.xml
virsh pool-start isos
virsh pool-autostart isos
rm -rf ~/isopool.xml

}

install_packages () {

yum update -y
yum install qemu-kvm qemu-img virt-manager libvirt libvirt-python libvirt-client virt-install virt-viewer bridge-utils -y
systemctl start libvirtd
systemctl enable libvirtd
systemctl disable firewalld
systemctl stop firewalld

}


interface_name=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | head -n 1 | sed 's/ //g')


install_packages
create_virsh_pool
create_virsh_network
configure_bridge
systemctl restart libvirtd
