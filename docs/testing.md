# Testing

## Fast Validation

1. Build the ISO:

```bash
./scripts/build-iso.sh
```

2. Boot the latest ISO in QEMU:

```bash
./scripts/run-qemu.sh
```

## Smoke Test Checklist

- Boot menu appears
- BIOS boot works in standard QEMU
- UEFI boot works in OVMF/QEMU
- Kernel and initramfs load correctly
- SDDM starts automatically
- Login works for user `null`
- KDE Plasma desktop appears
- `konsole` launches
- networking can be brought up
