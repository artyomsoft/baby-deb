# baby-deb

This repository contains scripts for build baby-deb - simple Debian based Linux distribution. You can run created disk image in qemu, or on real hardware. To run on real hardware you must to write the disk image to flash drive with _dd_ command or [_balenaEtcher_](https://etcher.balena.io/) and boot from this media.

To build _baby-deb_ image with the help of shell script:

```
sudo apt update && apt install -y debootstrap fdisk dosfstools kpartx qemu
sudo ./build-linux-image.sh --disk-image images/baby-deb.img
```

To build Building _baby-deb_ image with the help docker image:

```
sudo docker run -v .:/output --privileged -it --rm artyomsoft/baby-deb-builder --disk-image images/baby-deb.img
```

To create the Docker image for building baby-deb:

```
sudo docker build --no-cache -t baby-deb-builder .
```

To build _baby-deb_ image

```
sudo docker run -v .:/output --privileged -it --rm baby-deb-builder --disk-image images/baby-deb.img
```

To start _baby-deb_ in qemu

```
./start-qemu.sh --disk-image images/baby-deb.img
```

or

```
./start-qemu.sh --readonly-efi-vars off --disk-image images/baby-deb.img
```
