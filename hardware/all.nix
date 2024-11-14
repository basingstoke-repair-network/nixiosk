{ modulesPath, lib, config, pkgs, ... }:

# This tries to support all hardware that we can. It’s useful for ISO
# or PXE where we don’t know what kind of machine we’ll be running on.
# The resulting files will be very big (2G+).

{

  config = lib.mkIf (builtins.elem config.nixiosk.hardware ["iso" "pxe" "any"]) {

    hardware.enableRedistributableFirmware = true;

    boot.initrd.availableKernelModules = [
      # KMS
      "amdgpu" "i915" "nouveau"

      # QEMU support
      "virtio_net" "virtio_pci" "virtio_blk" "virtio_balloon" "virtio_console" "virtio_gpu"

      # VMware support.
      "mptspi" "vmw_balloon" "vmwgfx" "vmw_vmci" "vmw_vsock_vmci_transport" "vmxnet3" "vsock"

      # Hyper-V support.
      "hv_storvsc"
    ];

    networking.wireless.enable = true;

    systemd.services.qemu-guest-agent = lib.optionalAttrs (builtins.elem config.nixiosk.hardware ["qemu" ]) {
      description = "Run the QEMU Guest Agent";
      unitConfig.ConditionVirtualization = "qemu";
      serviceConfig = {
        ExecStart = "${pkgs.qemu.ga}/bin/qemu-ga";
        Restart = "always";
        RestartSec = 0;
      };
    };

    hardware.firmware = [ pkgs.wireless-regdb ];

  };

}
