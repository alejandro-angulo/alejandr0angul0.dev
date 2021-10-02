+++
title = "Arch Linux X1 Carbon 6"
date = "2020-07-30T17:56:45-07:00"
author = ""
authorTwitter = "" #do not include @
cover = ""
tags = ["info-dump"]
keywords = ["arch", "linux", "thinkpad", "X1", "carbon", "LUKS", "install"]
description = ""
showFullContent = false
+++

I recently picked up a 6th gen X1 Carbon so of course I wanted to install Arch Linux on it. This post documents the steps I took
in case I ever have to do this again. I used [ejmg's
guide](https://github.com/ejmg/an-idiots-guide-to-installing-arch-on-a-lenovo-carbon-x1-gen-6) guide, [HardenedArray's gist
guide](https://gist.github.com/HardenedArray/ee3041c04165926fca02deca675effe1), and the [Arch Linux wiki
page](https://wiki.archlinux.org/index.php/Lenovo_ThinkPad_X1_Carbon_(Gen_6)) as references.

_Note_: This was my setup as of July 2020ish. Things have changed since then.

## Setup

### Prepare Installation Media

This part is relatively straighforward. Check out the [arch wiki
page](https://wiki.archlinux.org/title/USB_flash_installation_medium).

### Prepare BIOS

BIOS -> Security -> Secure Boot -> Disable
BIOS -> Config  -> Thunderbolt(TM) 3 -> Thunderbolt BIOS Assist Mode: Enabled

Configure boot order to boot off USB
BIOS -> Startup -> Boot -> Move USB HDD to the top of the list (also moved USB FDD to 2nd since I wasn't sure which one I needed

Plug in USB

## Live Environment Setup

### Connect to WiFi Network

I was able to get everything set up with `iwctl`. Once you're in the `iwctl` prompt, use the `help` command to see available
commands.

```bash
# iwctl
[iwd]# device list

# Shows devices installed. Mine was wlan0

[iwd]# station wlan0 get-networks

# Shows available networks

[iwd]# station wlan0 connect $SSID

# Wrap your SSID in quotes if it has spaces
# Enter passphrase when prompted

[iwd]# exit
```

### Partition Drive

TODO: Rewrite this section to have more of a focus on what commands to run (too much time spent describing)

My device had two SSDs installed. `lsblk` showed them as `nvme0n1` and `nvme1n1`. My primary SSD was `nvme1n1` so I ran `gdisk
/dev/nmve1n1`. You can enter `?` to get a list of commands. I went ahead and deleted (`d`) all the existing partitions. Created an
EFI partition (`n`) on partition 1 with a size of 100 MiB (chose first sector and then `+100M` for the last sector) with hex code
EF00 (EFI partition). I created partition 2 to span the rest of the device. I tried having a separate boot partition but ran into
issues getting my system to boot up properly. It's probably possible to have a separate boot partition but it probably makes the
setup more complex. So, unless you know what you're doing, don't create any other partitions on this drive.

For my second drive I ran `gdisk /dev/nvme0n1` and left a single partition spanning the entire device with hex code 8300 (Linux
FS). This drive can be partitioned however you like.

I should zero my devices but I'm not that paranoid so I didn't. This could be done with `ddrescue` or with `cat` like so `cat
/dev/zero > /dev/nvme1n1 && cat /dev/zero /dev/nme0n1`.

### Setup filesystems

#### Encrypting Devices

Encrypt all partitions except for the EFI partition. This is done with `cryptsetup`'s `luksFormat` subcommand. `luksFormat` will
prompt for a password. **Do not** forget these passwords or you'll be locked out of your drives and be forced to reformat. The
passwords don't have to match. In fact, it's better to have a unique password for each one but **do not** forget the passwords. Once
the drives are encrypted, they need to be opened with the `luksOpen` subcommand. The last part of the `luksOpen` (`EncryptedBoot`
and `Secondary` below) subcommand is just a label and can be any value (just be sure to remain consistent -- these labels will be
used later on).

These are the commands I ran:

```bash
cryptsetup -c aes-xts-plain64 -h sha512 -s 512 --use-random --type luks1 luksFormat /dev/nvme1n1p2
cryptsetup -c aes-xts-plain64 -h sha512 -s 512 --use-random --type luks1 luksFormat /dev/nme0n1p1
cryptsetup luksOpen /dev/nvme1n1p2 EncryptedBoot
cryptsetup luksOpen /dev/nvme0n1p1 Secondary
```

When I first tried setting this up I realized I had accidentally encrypted the EFI partition (saw an error when I tried to mount
it later on). Fixing this is easy though, just close the partition with `cryptsetup luksClose EncryptedBoot`. Replace
`EncryptedBoot` with whatever label was given (this can be checked with `lsblk`). Once the partition is closed, reformat it with
FAT32 again (see the [`Create FileSystems`](#create-filesystems) section).

#### LVM

Use the Linux Volume Manager (LVM) to create a swap volume on the primary drive (labeled `EncryptedBoot`). Setup volumes for the
secondary drive (labeled `Secondary`) while we're at it.

```bash
pvcreate /dev/mapper/EncryptedBoot
vgcreate Arch /dev/mapper/EncryptedBoot
lvcreate -L 16G -n swap
lvcreate -l 100%FREE Arch -n root
pvcreate /dev/mapper/Secondary
vgcreate Data /dev/mapper/Secondary
lvcreate -l 100%FREE Data -n root
```

#### Create Filesystems

Create a FAT32 filesystem for the EFI partition, set up the swap partition, and format the rest with ext4.


```bash
mkfs.vfat -F 32 /dev/nvme1n1p1
mkswap /dev/mapper/Arch-swap
mkfs.ext4 /dev/mapper/Arch-root
mkfs.ext4 /dev/mapper/Data-root
```

## Installation

### Bootstrap

Now that the drives are ready, the actual installation can begin. Mount the drives first.

```bash
mount /dev/mapper/Arch-root /mnt
swapon /dev/mapper/Arch-swap
mkdir /mnt/boot
mkdir -p /mnt/mnt/data
mount /dev/mapper/Data-root /mnt/mnt/data
mkdir /mnt/efi
mount /dev/nvme1n1p1 /mnt/efi
```

Install a base set of packages. More will be installed later on, this is just a minimal set of packages.

```bash
pacstrap /mnt base base-devel grub efibootmgr dialog wpa_supplicant linux linux-headers vim dhcpcd netctl lvm2 linux-firmware iwd
man-db man-pages
```

_Note:_ Later on when I was configuring my network after Arch had been installed I realized I didn't use `netctl` or `dhcpcd`.
These can probably be left out. Not sure if `wpa_supplicant` needs to be installed here either. `vim` could be replaced with a
different editor like `emacs` or `nano`.

One last step before chroot'ing into the Arch installation is to write an `/etc/fstab` file. This can be generated with `genfstab`.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

Before continuing, review `/mnt/etc/fstab` and make any necessary changes (I didn't need to make any changes but it's a good idea
to check). It's finally time to chroot.

```bash
arch-chroot /mnt /bin/bash
```

The root is now the same as the Arch install's root.

### Housekeeping

Find the local timezone in `/usr/share/zoneinfo` and set the system timezone.

```bash
ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
```

Set the hostname. I decided on naming my computer `carbon`.

```bash
echo carbon > /etc/hostname
```

Set the locale. Go through `/etc/locale.gen` and uncomment the relevant lines. I only uncommented `en_US.UTF-8 UTF-8`. After that,
generate localization files.

```bash
echo LANG=en_US.UTF-8 > /etc/locale.conf
locale-gen
```

Set the root password and create a user account (bad practice to run as root).

```bash
passwd
useradd -m -G wheel -s /bin/bash alejandro
```

Replace `alejandro` with your username. `sudo` will later be configured to allow users in the `wheel` group.

### More Encryption Configuration

When the system boots up, the bootloader (I'll be using `grub`) will need to read `/boot` and the system will need access to any
other volumes specified in the fstab file.  Without any extra configuration, there will be a passphrase prompt for every volume.
LUKS devices have multiple "key slots." It's possible to use a key file to fill in one of the key slots and later pass that file
in to open (decrypt) a LUKS device. This makes it possible to have `grub` handle decryption of root and swap without requiring the
user to enter multiple passphrases (which is clunky and error-prone). Other volumes (my data root volume) can be configured in
`/etc/crypttab` (similar to `/etc/fstab`) to also be automatically opened.

Generate a random keyfile.

```bash
cd /
dd bs=512 count=4 if=/dev/random of=crypto_keyfile.bin iflag=fullblock
```

This keyfile should **never** be shared. In fact, no user should have access to this file. The [arch wiki
warns](https://wiki.archlinux.org/index.php/Dm-crypt/Device_encryption#With_a_keyfile_embedded_in_the_initramfs) that initramfs's
permissions should be set to 600 as well.

```bash
chmod 000 /crypto_keyfile.bin
chmod 600 /boot/initramfs-linux*
```

Add the keyfile to the LUKS devices.

```bash
cryptsetup luksAddKey /dev/nvme1n1p2 /crypto_keyfile.bin
cryptsetup luksAddKey /dev/nvme0n1p1 /crypto_keyfile.bin
# Use the commands below to verify the keyfile has been added.
cryptsetup luksDump /dev/nvme1n1p2  # Should see slots 0 and 1 occupied
cryptsetup luksDump /dev/nvme0n1p1  # Should see slots 0 and 1 occupied
```

Configure automatic opening of the data volume through `crypttab`. Edit `/etc/crypttab`

```plaintext
# SNIP ...
# <name>       <device>                                     <password>              <options>
Secondary      /dev/nvme0n1p1                               /crypto_keyfile.bin     discard
# SNIP ...
```

The `discard` option has to do with the `TRIM` command and is basically a performance optimization. Read more about it on
[wikipedia](https://en.wikipedia.org/wiki/Trim_(computing)).

Edit the `mkinitpcio` configuration file (`/etc/mkinitpcio.conf`) to setup decryption.

```plaintext
# SNIP ...
FILES=(/crypto_keyfile.bin)
# SNIP ...
HOOKS=(base udev autodetect modconf block keymap encrypt lvm2 resume filesystems keyboard fsck)
```

Generate the initrd image.

```bash
mkinitpcio -p linux
```

`grub` now has to be configured so it knows `/boot` is encrypted. Uncomment the `GRUB_ENABLE_CRYPTODISK=y` line in
`/etc/default/grub`. Once that's done `grub` can be installed.

```bash
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ArchLinux
```

Open up `/etc/default/grub` again and edit the `GRUB_CMDLINE_LINUX` line so it looks like this
`GRUB_CMDLINE_LINUX=cryptdevice/nvme1n1p2:EncryptedBoot:allow-discards resume=/dev/mapper/Arch-swap`.

The `allow-discards` option also has to do with `TRIM`. Now the `grub` configuration is ready to be generated.

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

That's it. The system should now be bootable. Exit, reboot, and pray.

```bash
exit
umount -R /mnt
swapoff -a
reboot
```

You should be prompted for your passphrase once. If you get the passphrase wrong you'll be dropped into grub rescue mode. Hit
`ctrl+alt+delete` and try again (or reboot by holding down the power button if that doesn't work). Don't be frustrated if this
doesn't work on the first try. There are a lot of steps in setting this up and mistakes happen (I didn't get this right at first
either).

### First Logon

Log in to your system as root and alow users in the wheel group to use `sudo`. Run `visudo`, if you get an error saying no editor
found just prepend the editor's path like this `EDITOR=/usr/bin/vim visudo`. Uncomment the following line `%wheel ALL=(ALL) ALL`.
You can log out and log in with your own user account now.

### Setup WiFi

`iwd` can be used to manage the network with the proper configuration. Edit `/etc/iwd/main.conf`

```plaintext
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
```

The `EnableNetworkConfiguration` setting allows `iwd` to handle stuff like DHCP. The `NameResolvingService` configures DNS. I
decided to use `systemd-resolved` mostly just because I already had it installed (part of the `systemd` package). Enable and start
`systemd-resolved` and `iwd`.

```bash
systemctl enable systemd-resolved
systemctl enable iwd
systemctl start systemd-resolved
systemctl start iwd
```

Follow the same steps as before to connect to wifi (run `iwctl`).

### Install Additional Packages

The default mirrorlist was kept earlier but `reflector ` can be used to choose mirrors. The `reflector` command below will filter
the 200 most recently updated https servers and choose the 200 fastest ones.

```bash
pacman -S reflector
reflector --verbose -l 200 -n 20 -p https --sort rate --save /etc/pacman.d/mirrorlist
```

A [pacman hook](https://wiki.archlinux.org/index.php/Pacman#Hooks) can be setup to automatically run reflector when
`pacman-mirrorlist` is updated (this package contains the official mirrorlist). Create `/etc/pacman.d/hooks/mirrorupgrade.hook`

```plaintext
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman-mirrorlist with reflector and removing pacnew...
When = PostTransaction
Depends = reflector
Exec = /bin/sh -c "reflector -l 200 -n 20 -p https --sort rate --save /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
```

Make sure everything is up-to-date.

```bash
sudo pacman -Syyu
```

Some packages are only available from the Arch User Repository (AUR). `pacman` won't handle these packages, but there are AUR
helpers that can. Install `yay`.

```bash
sudo pacman -S git
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
# clean up
cd ..
rm -rf yay
```

Set up `zsh`.

```bash
yay -S zsh oh-my-zsh-git
zsh  # runs setup
chsh -s /usr/bin/zsh  # set zsh as default shell
cp /usr/share/oh-my-zsh/zshrc ~/.zshrc
```

I normally use `i3` but I've been wanting to switch to `wayland` so I went with `sway` since it's the closest thing (the about
section on GitHub bills it as an "i3-compatible Wayland compositor").

```bash
yay -S sway swaylock swayidle waybar xorg-server-xwayland
# Can probably leave the 2 lines below out
mkdir -p ~/.config/sway
cp /etc/sway/config ~/.config/sway
mkdir -p ~/.config/waybar
cp /etc/xdg/waybar/* ~/.config/waybar
```
I edited my sway config to mimic my i3 config so I needed to grab a few packages first.

```bash
yay -S termite bemenu-wlroots
```

`termite` is the terminal emulator that I'm used to an I used `bemenu` as an alternative to `dmenu`.

With that out of the way, I started up sway and realized I still needed a web browser.

```bash
yay -S firefox
```

Firefox wouldn't run when I tried to start it. I came to find out that Firefox's wayland support needs to be enabled so I updated my
`~/.zprofile` with an environment variable to enable wayland support in Firefox.

```bash
echo "export MOZ_ENABLE_WAYLAND=1" >> ~/.zprofile
```

After restarting sway, I was able to run Firefox. I ran into my next issue (seems like a recurring theme) soon after. Everything
on the screen seemed too big. The scaling factor for my display was too large (first world problem, I know). Luckily for me sway
supports (but doesn't reccommend) fractional scaling. I got my display's name using `swaymsg`.

```bash
swaymsg -t get_outputs
```

Then I added a line to my sway config to set a custom scaling factor: `output eDP-1 scale 1.75`. `eDP-1` is the name of my
display, as reported by `swaymsg`.

Next thing I wanted to fix were the fonts. I didn't like the current ones so I installed all the [nerd
fonts](https://ww(w.nerdfonts.com/). When I looked at the AUR page for `nerd-fonts-complete` there was a pinned comment that
suggested grabbing the tarball manually since it was so large (~2GB).

```bash
yay -S wget
mkdir -p ~/.local/share/fonts
ln -s /usr/lib/nerd-fonts-complete/*.sh ~/.local/share/fonts/
echo source ~/.local/share/fonts/i_all.sh >> ~/.zshrc
```

#### Notifications

```bash
yay -S mako libnotify
add line to sway config
```

#### Terminal Themes

I use themes defined in `base16-shell`.

```bash
git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
```

Follow set up directions in [the repo](https://github.com/chriskempson/base16-shell). I use `base16_darktooth`.

#### Sound

I use pulseaudio

```bash
yay -S pulseaudio pulseaudio-alsa pamixer pulseaudio-bluetooth
```

#### Spotify TUI

Spotify can be controlled from the terminal using `spotify-tui` and `spotifyd`. Doesn't have all the features as the official
client but it's

```bash
yay -S spotify-tui spotifyd
```

Set up keyring to use with spotify

```bash
yay -S gnome-keyring libsecret  # seahorse too?, not sure how to manage purely from cli
```

Edit `/etc/pam.d/login` to add in `auth optional pam_gnome_keyring.so` and `session optional pam_gnome_keyring.so auto_start`.
Mine looks like this.

```plaintext
#%PAM-1.0

auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
```

Update the `passwd` file to include `password optional pam_gnome_keyring.so`.

We need to run the following when sway starts.

```bash
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
```

Normally this would be added in `~/.xinitrc` but there isn't (afaik) a wayland equivalent. So I created a start script for sway.

```bash
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
sway
```

Store spotify password in keystore `secret-tool --label='Spotify' application rust-keyring service spotifyd
username <your-username>`. You'll be prompted to create a default keyring if one hasn't already been created.

Create systemd unit file and run spotifyd

```bash
mkdir -o ~/.config/systemd/user/
get https://raw.githubusercontent.com/Spotifyd/spotifyd/blob/master/contrib/spotifyd.service -O ~/.config/systemd/user/spotifyd.service
systemctl --user start spotifyd.service  # do not run these two with sudo
systemctl --user enable spotifyd.service
```

Run `spt` and it'll guide you through setup. See the [their readme](https://github.com/Rigellute/spotify-tui#using-with-spotifyd)
for instructions.

```bash
git clone --separate-git-dir=$HOME/.myconf /path/to/repo $HOME/myconf-tmp
rm -r ~/myconf-tmp/
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'  # Add this into .bashrc/.zshrc
```

#### Backlight Control

```bash
yay -S light
usermod -a -G video alejandro  # need to be in video group to control backlight
# below 2 reload udev rules, so light doesn't requre root permissions
sudo udevadm control --reload-rule
sudo udevadm trigger
# Above 2 commands didn't work for me, but did after a reboot
# installed wshowkeys and used it to figure out what keys to bind to light commands in sway config
```

#### Terminal prompt

```bash
yay -S zsh-theme-powerlevel10k-git
echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
```

Restart terminal and p10k config wizard will run (or manually run `p10k configure`)

#### Vim plugin manager

```
mkdir -p ~/.vim/bundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```

#### Power Management

Read this for power stuffs: https://github.com/erpalma/throttled

```bash
yay -S throttled
systemctl enable --now lenovo_fix.service
```

#### Network printer

```bash
yay -S cups
systemctl enable --now org.cups.cupsd.service
yay -S nss-mdns avahi
systemctl enable --now avahi-daemon
```

Update `/etc/nsswitch.conf` to include `hosts: ... mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns ...`

Browse to `localhost:631` to configure printer (Brother HL-L2350 for me) (`yay -S brother-hll2350dw`) (`yay -S ghostscript`)

#### QMK

```
yay -Q python-pip
pip install --user qmk
qmk setup
# CD into qmk directory
make crkbd:default
```

Edit `/etc/udev/rules.d/55-caterina.rules`

```plaintext
# ModemManager should ignore the following devices
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2a03", ATTRS{idProduct}=="0036", TAG+="uaccess", RUN{builtin}+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0036", TAG+="uaccess", RUN{builtin}+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b4f", ATTRS{idProduct}=="9205", TAG+="uaccess", RUN{builtin}+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b4f", ATTRS{idProduct}=="9203", TAG+="uaccess", RUN{builtin}+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
```

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
qmk flash
```

Had to reboot before this worked for me. Because of avrdude? `qmk doctor` showed udev rules were setup. Had to add user to `uucp`
group to write to device.
