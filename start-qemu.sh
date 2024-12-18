# /bin/bash

usage() {
    name=$1
    echo "Usage:"
    echo "    $name [--readonly-efi-vars [on|off]] [--disk-image filename]"
    exit 1
}

readonly_efi_vars="on"
disk_image="disk.img"

while :; do
    case "$1" in
    --readonly-efi-vars)
        readonly_efi_vars="$2"
        shift
        ;;
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

if [[ "$readonly_efi_vars" != "on" && "$readonly_efi_vars" != "off" ]]; then
    echo "readonly_efi_vars contain's the invalid value $readonly_efi_vars"
    usage $0
    exit 1
fi

if [[ ! -e $disk_image ]]; then
    echo "File $disk_image doesn't exist"
    usage $0
    exit 1
fi

echo "Starting qemu... readonly_efi_vars=$readonly_efi_vars disk_image=$disk_image"

qemu-system-x86_64 \
    -m 4096m \
    -drive if=pflash,format=raw,readonly=on,file=ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,readonly=$readonly_efi_vars,file=ovmf/OVMF_VARS.fd \
    -drive format=raw,file=$disk_image
