# https://www.microsoft.com/en-us/windows/windows-11-specifications
# https://sysguides.com/install-a-windows-11-virtual-machine-on-kvm#10-110-enable-trusted-platform-module-tpm
packages:
{ name
, uuid
, memory ? { count = 4; unit = "GiB"; }
, storage_vol_path
, mac_address
, install_vol_path ? null
, ovmf_code_path
, ovmf_vars_path
, nvram_path
, ...
}:
let
  base = import ./base.nix packages
    {
      inherit name uuid memory storage_vol_path mac_address install_vol_path;
    };
in
base //
{
  vcpu.count = 2;
  os = base.os //
  {
    loader =
      {
        readonly = true;
        type = "pflash";
        # path = "${packages.OVMF.fd}/FV/OVMF_CODE.ms.fd";
        # unavailable, see https://github.com/NixOS/nixpkgs/issues/288184
        path = ovmf_code_path;
      };
    nvram =
      {
        # template = "${packages.OVMF.fd}/FV/OVMF_VARS.ms.fd";
        template = ovmf_vars_path;
        path = nvram_path;
      };
  };
  features = base.features //
  {
    hyperv =
      {
        mode = "custom";
        relaxed = { state = true; };
        vapic = { state = true; };
        spinlocks = { state = true; retries = 8191; };
        vpindex = { state = true; };
        runtime = { state = true; };
        synic = { state = true; };
        stimer = { state = true; direct = { state = true; }; };
        reset = { state = true; };
        vendor_id = { state = true; value = "KVM Hv"; };
        frequencies = { state = true; };
        reenlightenment = { state = true; };
        tlbflush = { state = true; };
        ipi = { state = true; };
      };
  };
  cpu = { mode = "host-passthrough"; };
  clock = base.clock //
  {
    offset = "localtime";
    timer = base.clock.timer ++ [{ name = "hypervclock"; present = true; }];
  };
  pm =
    {
      suspend-to-mem = { enabled = false; };
      suspend-to-disk = { enabled = false; };
    };
  devices = base.devices //
  {
    disk =
      [
        {
          type = "file";
          device = "disk";
          driver =
            {
              name = "qemu";
              type = "qcow2";
              cache = "none";
              discard = "unmap";
            };
          source =
            {
              file = storage_vol_path;
            };
          target = { dev = "vda"; };
        }
        {
          type = "file";
          device = "cdrom";
          driver =
            {
              name = "qemu";
              type = "raw";
            };
          source =
            if builtins.isNull install_vol_path then null else
            {
              file = install_vol_path;
              startupPolicy = "mandatory";
            };
          target =
            {
              bus = "sata";
              dev = "hdc";
            };
          readonly = true;
        }
      ];
    channel = base.devices.channel ++
    [
      {
        type = "spiceport";
        source =
          {
            channel = "org.spice-space.webdav.0";
          };
        target =
          {
            type = "virtio";
            name = "org.spice-space.webdav.0";
          };
      }
    ];
    tpm =
      {
        model = "tpm-crb";
        backend =
          {
            type = "emulator";
            version = "2.0";
          };
      };
    graphics = base.devices.graphics //
    {
      listen = { type = "none"; };
      gl = { enable = false; };
    };
    video.model = base.devices.video.model //
    {
      acceleration = { accel3d = false; };
    };
  };
}