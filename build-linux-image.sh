#!/bin/bash

usage() {
    name=$1
    echo "Usage:"
    echo "    $name [--disk-image filename]"
    exit 1
}

disk_image="disk.img"

while :; do
    case "$1" in
    --disk-image)
        disk_image="$2"
        shift
        ;;
    --)
        shift
        break
        ;;
    -*)
        echo "Invalid arg: $1"
        usage $0
        exit 1
        ;;
    *)
        break
        ;;
    esac
    shift
done

run_in_chroot() {

    local rootfs_dir=$1
    local func=$2
    for dir in dev dev/pts proc sys run; do mount --bind /$dir $rootfs_dir/$dir; done

    LANG=C.UTF-8 chroot "$rootfs_dir" /bin/bash -c "$func"

    for dir in dev/pts dev proc sys run; do umount $rootfs_dir/$dir; done

}

configure_rootfs() {

    set_password "root" "live"
    apt install -y firmware-iwlwifi network-manager
    echo baby-deb >/etc/hostname
    apt install -y sudo
    create_user "root" "live"
    apt install -y mc wget efibootmgr
}

create_disk_image() {

    local image_file_name=$1
    fallocate -l 3G $image_file_name
    echo -e ",200M,U\n,+\n" | sfdisk -X gpt $image_file_name && sync

}

map_disk_image() {

    local image_file_name=$1
    block_device=$(losetup --show -f $image_file_name)
    local loop_name="${block_device##*/}"
    kpartx -av $block_device
    esp_partition="/dev/mapper/${loop_name}p1"
    rootfs_partition="/dev/mapper/${loop_name}p2"
}

get_partition_id() {

    local partition=$1
    blkid -s PARTUUID -o value $partition
}

get_filesystem_id() {

    local partition=$1
    blkid -s UUID -o value $partition
}

unmap_disk_image() {

    local block_device=$1
    kpartx -dv $block_device
    losetup -d $block_device
}

mount_file_system() {

    local partition=$1
    local mount_point=$2
    mkdir -p $mount_point
    mount $partition $mount_point
}

make_startup_nsh() {

    local file_path=$1
    local rootfs_id=$(get_filesystem_id $2)
    local linux=$3
    local initrd=$4
    local cmd_line=$5

    echo "$linux initrd=$initrd root=UUID=$rootfs_id $cmd_line" >$file_path
}

setup_fstab() {

    local rootfs_path=$1
    local rootfs_partition=$2
    local esp_partition=$3
    local rootfs_id=$(get_filesystem_id $rootfs_partition)
    local esp_partition_id=$(get_filesystem_id $esp_partition)

    mkdir -p $rootfs/efi
    cat >$rootfs_path/etc/fstab <<HEREDOC
UUID=$rootfs_partition_id / ext4 noatime,errors=remount-ro  0  1
UUID=$esp_partition_id /efi vfat umask=0077 0 1
HEREDOC
}

create_user() {

    local username=$1
    local password=$2

    useradd -m -s /bin/bash $username
    usermod -aG sudo $username
    echo "User $username is created"
    set_password $username $password
}

set_password() {

    local username=$1
    local password=$2

    echo "$username:$password" | chpasswd
    echo "Password for $username is set"
}

create_linux_image() {

    local output_file_path=$1
    local output_file_name="$(basename $output_file_path)"
    local output_file_dir="$(dirname $output_file_path)"

    if [[ $CONTAINER == "docker" ]]; then
        output_file_dir="$OUTPUT_DIR/$output_file_dir"
    else
        output_file_dir="$(realpath $output_file_dir)"
    fi

    mkdir -p build && cd build

    work_dir=$(pwd)
    create_disk_image disk.img
    map_disk_image disk.img
    mkfs.fat $esp_partition
    mkfs.ext4 $rootfs_partition
    local esp_path=$work_dir/mnt/esp
    local rootfs_path=$work_dir/mnt/rootfs
    mount_file_system $esp_partition $esp_path
    mount_file_system $rootfs_partition $rootfs_path
    debootstrap \
        --include=linux-image-amd64,firmware-linux \
        --components=main,contrib,non-free-firmware \
        --arch=amd64 bookworm $rootfs_path https://deb.debian.org/debian
    run_in_chroot $rootfs_path configure_rootfs
    wget https://github.com/pbatard/UEFI-Shell/releases/download/24H2/shellx64.efi
    mkdir -p $esp_path/efi/boot
    mv -v shellx64.efi $esp_path/efi/boot/bootx64.efi
    cp -v $rootfs_path/boot/vmlinuz* $esp_path/vmlinuz
    cp -v $rootfs_path/boot/initrd.img* $esp_path/initrd.img
    cp -v $rootfs_path/boot/config* $esp_path/
    setup_fstab $rootfs_path $rootfs_partition $esp_partition
    make_startup_nsh $esp_path/startup.nsh $rootfs_partition "\vmlinuz" "/initrd.img" "quiet"
    sync
    umount $work_dir/mnt/esp
    umount $work_dir/mnt/rootfs
    unmap_disk_image $block_device
    chmod 666 disk.img

    mkdir -p $output_file_dir

    mv -v disk.img $output_file_dir/$output_file_name

    cd ..

    rm -r build

}

export -f configure_rootfs
export -f create_user
export -f set_password

set -x -e
create_linux_image $disk_image
