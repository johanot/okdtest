{
  runtimeShell, qemu, qemu_kvm, vde2, writeShellScript,
  bootDisk,
  name,
  vmConfig,
}:
  writeShellScript "start-vm-${name}.sh" ''
    # Start QEMU.
    exec ${qemu_kvm}/bin/qemu-kvm \
        -snapshot \
        -name ${name} \
        -m ${toString vmConfig.memorySize} \
        -smp ${toString vmConfig.cores} \
        -device virtio-rng-pci \
        -nic user,model=virtio,hostfwd=tcp::${toString vmConfig.sshHostPort}-:22 \
        -device virtio-net-pci,netdev=vlan1,mac=${vmConfig.mac} \
        -netdev vde,id=vlan1,sock="$TESTTMPDIR/vde" \
        -drive if=virtio,file=${bootDisk}/disk.img \
        -fw_cfg name=opt/com.coreos/config,file=${vmConfig.ignition} \
        $QEMU_OPTS \
        "$@"
''
