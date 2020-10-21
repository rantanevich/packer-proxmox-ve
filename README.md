Packer: Proxmox VE

This builds an up-to-date [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) Vagrant Base Box.

Currently this targets Proxmox VE 6.2.

Usage
-----

Builds an own box:
```sh
packer build proxmox-ve.json
```

Uses the ready-made box:

```sh
vagrant init -m rantanevich/proxmox --provider=libvirt
vagrant up
```

Access the Proxmox API or Proxmox Web UI (**https://<IPv4_box_address>:8006/**):
```
username: root/vagrant
password: vagrant
```

For a cluster example see [rgl/proxmox-ve-cluster-vagrant](https://github.com/rgl/proxmox-ve-cluster-vagrant).


## Packer boot_command


As Proxmox does not have any way to be pre-seeded, this environment has to answer all the
installer questions through the packer `boot_command` interface. This is quite fragile, so
be aware when you change anything. The following table describes the current steps and
corresponding answers.

| step                              | boot_command               |
|----------------------------------:|----------------------------|
| select "Intall Proxmox VE"        | `<enter>`                  |
| wait for boot                     | `<wait30s>`                |
| agree license                     | `<enter><wait>`            |
| target disk                       | `<enter><wait>`            |
| type country                      | `Belarus<tab>`             |
| timezone                          | `<tab>`                    |
| keyboard layout                   | `<tab>`                    |
| advance to the next button        | `<tab>`                    |
| advance to the next page          | `<enter>`                  |
| password                          | `vagrant<tab>`             |
| confirm password                  | `vagrant<tab>`             |
| email                             | `pve@example.com<tab>`     |
| advance to the next button        | `<tab>`                    |
| advance to the next page          | `<enter>`                  |
| hostname                          | `pve.example.com<tab>`     |
| ip address                        | `<tab>`                    |
| netmask                           | `<tab>`                    |
| gateway                           | `<tab>`                    |
| DNS server                        | `<tab>`                    |
| advance to the next button        | `<tab>`                    |
| advance to the next page          | `<enter>`                  |
| install                           | `<enter>`                  |
| wait 1m for install to finish     | `<wait2m>`                 |
| reboot                            | `<enter>`                  |
