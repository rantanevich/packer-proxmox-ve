#!/usr/bin/env bash
set -eux

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# switch to the non-enterprise repository.
# see https://pve.proxmox.com/wiki/Package_Repositories
rm -f /etc/apt/sources.list.d/pve-enterprise.list
echo 'deb http://download.proxmox.com/debian/pve buster pve-no-subscription' > /etc/apt/sources.list.d/pve.list

# switch the apt mirror to Belarus.
sed -i -E 's,ftp.debian,ftp.by.debian,' /etc/apt/sources.list

# upgrade.
apt-get update
apt-get dist-upgrade -y

# use traditional interface names like eth0 instead of enp0s3
# by disabling the predictable network interface names.
# disable to show boot menu
sed -i -E 's,^(GRUB_CMDLINE_LINUX=).+,\1"net.ifnames=0",' /etc/default/grub
sed -i -E 's,^(GRUB_TIMEOUT),\1=0,' /etc/default/grub
update-grub

# configure the network for working in a vagrant environment.
# NB proxmox has created the vmbr0 bridge and placed eth0 on the it, but
#    that will not work, vagrant expects to control eth0. so we have to
#    undo the proxmox changes.
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

iface eth0 inet manual

auto vmbr0
iface vmbr0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
EOF

# set the timezone.
timedatectl set-timezone Europe/Minsk

# remove old kernel packages.
# NB as of pve 5.2, there's a metapackage, pve-kernel-4.15, then there are the
#    real kernels at pve-kernel-*-pve (these are the ones that are removed).
pve_kernels=$(dpkg-query -f '${Package}\n' -W 'pve-kernel-*-pve')
for pve_kernel in $pve_kernels; do
    if [[ $pve_kernel == "pve-kernel-$(uname -r)" ]]; then
        apt-get remove -y --purge $pve_kernel
    fi
done

# passwordless sudo for a vagrant user
apt-get install -y sudo
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant

# create the vagrant user
useradd -G sudo -m -s /bin/bash vagrant
echo 'vagrant:vagrant' | chpasswd

# allow access with the insecure vagrant public key.
install -d -m 700 /home/vagrant/.ssh
pushd /home/vagrant/.ssh
wget -q --no-check-certificate https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -O authorized_keys
chmod 600 authorized_keys
chown -R vagrant:vagrant .
popd

# create proxmox user and attach Administrator role to him
pveum useradd vagrant@pam
pveum passwd vagrant@pam --password vagrant
pveum aclmod / -user vagrant@pam -role Administrator

# install rsync and sshfs to support shared folders in vagrant.
apt-get install -y rsync sshfs

# disable the DNS reverse lookup on the SSH server. this stops it from
# trying to resolve the client IP address into a DNS domain name, which
# is kinda slow and does not normally work when running inside VB.
sed -E 's,^#*(UseDNS).+,\1 no,' /etc/ssh/sshd_config
sed -E 's,^#*(GSSAPIAuthentication).+,\1 no,' /etc/ssh/sshd_config

# reset the machine-id.
# NB systemd will re-generate it on the next boot.
# NB machine-id is indirectly used in DHCP as Option 61 (Client Identifier), which
#    the DHCP server uses to (re-)assign the same or new client IP address.
# see https://www.freedesktop.org/software/systemd/man/machine-id.html
# see https://www.freedesktop.org/software/systemd/man/systemd-machine-id-setup.html
echo '' > /etc/machine-id
rm -f /var/lib/dbus/machine-id

# reset the random-seed.
# NB systemd-random-seed re-generates it on every boot and shutdown.
# NB you can prove that random-seed file does not exist on the image with:
#       sudo virt-filesystems -a ~/.vagrant.d/boxes/proxmox-ve-amd64/0/libvirt/box.img
#       sudo guestmount -a ~/.vagrant.d/boxes/proxmox-ve-amd64/0/libvirt/box.img -m /dev/pve/root --pid-file guestmount.pid --ro /mnt
#       sudo ls -laF /mnt/var/lib/systemd
#       sudo guestunmount /mnt
#       sudo bash -c 'while kill -0 $(cat guestmount.pid) 2>/dev/null; do sleep .1; done; rm guestmount.pid' # wait for guestmount to finish.
# see https://www.freedesktop.org/software/systemd/man/systemd-random-seed.service.html
# see https://manpages.debian.org/stretch/manpages/random.4.en.html
# see https://manpages.debian.org/stretch/manpages/random.7.en.html
# see https://github.com/systemd/systemd/blob/master/src/random-seed/random-seed.c
# see https://github.com/torvalds/linux/blob/master/drivers/char/random.c
systemctl stop systemd-random-seed
rm -f /var/lib/systemd/random-seed

# clean packages.
apt-get -y autoremove
apt-get -y clean

# zero the free disk space -- for better compression of the box file.
fstrim -v /
