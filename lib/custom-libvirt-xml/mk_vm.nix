{ pkgs, lib, ... }:

let
  nullOrMiss = set: attr: (set.${attr} or null) != null;
in {
  mkVm = { 
    vmName ? "",
    vmTitle ? "",
    config ? {},
    cdIso,
    qemu,
    cpu,
    drives,
    devices,
    machine
  }: let
    # BASIC
    machineVersion =
      if vmName == "" then throw
        "vmName must be set!"
      else if vmTitle == "" then throw
        "vmTitle must be set!"
      else if ! (
        config.virtualisation.libvirtd.qemu ? ovmfOverride
        && config.virtualisation.libvirtd.qemu.ovmfOverride ? fd
      ) then throw
        "virtualisation.libvirtd.qemu.ovmfOverride must be set!"
      else if ! (cdIso == null || cdIso == [] || (builtins.typeOf cdIso) == "list") then throw
        "cdIso must be a list of paths!"
      else if !(builtins.pathExists qemu) then throw
        "qemu must be a path!"
      else
        machine;
    cfgFd = "${config.virtualisation.libvirtd.qemu.ovmfOverride.fd}/FV";
    # DRIVES
    driveDefaults = {
      C = { # System drive, auto-snapshotted.
        enable = true;
        location = "/vm_images/${vmName}/drive_c.img";
        largeBlk = true;
      };
      D = { # Large drive, usually not auto-snapshotted.
        enable = true;
        location = "/vm_images/common/drive_d.img";
        largeBlk = true;
      };
      S = { # SSD-only drive, usually not auto-snapshotted.
        enable = false;
        location = "/vm_images/speed/drive_s.img";
        largeBlk = true;
      };
      O = { # Old drive, read-only.
        enable = false;
        location = "/vm_images/old/${vmName}/drive_c.img";
        largeBlk = false;
      };
    };
    driveSettings = {
      C = if (nullOrMiss drives "C") then {
        enable = if (nullOrMiss drives.C "enable") then drives.C.enable else driveDefaults.C.enable;
        location = if (nullOrMiss drives.C "location") then drives.C.location else driveDefaults.C.location;
        largeBlk = if (nullOrMiss drives.C "largeBlk") then drives.C.largeBlk else driveDefaults.C.largeBlk;
      } else driveDefaults.C;
      D = if (nullOrMiss drives "D") then {
        enable = if (nullOrMiss drives.D "enable") then drives.D.enable else driveDefaults.D.enable;
        location = if (nullOrMiss drives.D "location") then drives.D.location else driveDefaults.D.location;
        largeBlk = if (nullOrMiss drives.D "largeBlk") then drives.D.largeBlk else driveDefaults.D.largeBlk;
      } else driveDefaults.D;
      S = if (nullOrMiss drives "S") then {
        enable = if (nullOrMiss drives.S "enable") then drives.S.enable else driveDefaults.S.enable;
        location = if (nullOrMiss drives.S "location") then drives.S.location else driveDefaults.S.location;
        largeBlk = if (nullOrMiss drives.S "largeBlk") then drives.S.largeBlk else driveDefaults.S.largeBlk;
      } else driveDefaults.S;
      O = if (nullOrMiss drives "O") then {
        enable = if (nullOrMiss drives.O "enable") then drives.O.enable else driveDefaults.O.enable;
        location = if (nullOrMiss drives.O "location") then drives.O.location else driveDefaults.O.location;
        largeBlk = if (nullOrMiss drives.O "largeBlk") then drives.O.largeBlk else driveDefaults.O.largeBlk;
      } else driveDefaults.O;
    };
    drivesCount = lib.count (d: d.enable) (lib.attrValues driveSettings);
    drivesXml = with lib; with builtins; concatStrings (
      imap0 (index: drive: ''
''\n    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native' discard='unmap' detect_zeroes='unmap'/>
      <source file='${drive.location}'/>${if drive.largeBlk then "
      <blockio logical_block_size='4096' physical_block_size='16384' discard_granularity='16384'/>" else ""}
      <target dev='sd${substring index 1 "abcdefghijklmnopqrstuvwxyz"}' bus='scsi' removable='off'/>
      <address type='drive' controller='0' bus='0' target='0' unit='${toString index}'/>
    </disk>''
      ) (attrValues (filterAttrs (_: drive: drive.enable) driveSettings))
    );
    # COMPUTE VALUES
    vmRamGb = builtins.readFile(
      pkgs.runCommand "vm-ram" {
        time = builtins.currentTime;
        preferLocalBuild = true;
        allowSubstitutes = false;
      } ''
        #!${pkgs.bash}/bin/bash
        TOTAL_RAM_KB=$(${pkgs.gnugrep}/bin/grep MemTotal /proc/meminfo | ${pkgs.gawk}/bin/awk '{ print $2 }')
        TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1048576 + 1))
        MIN_REQUIRED_GB=14
        if [ "$TOTAL_RAM_GB" -lt "$MIN_REQUIRED_GB" ]; then
            ${pkgs.coreutils}/bin/echo "Error: System needs at least 14GB RAM" >&2
            exit 1
        fi
        RAM_75_PERCENT=$((TOTAL_RAM_GB * 75 / 100))
        RAM_MINUS_6GB=$((TOTAL_RAM_GB - 6))
        if [ $RAM_75_PERCENT -lt $RAM_MINUS_6GB ]; then
            ${pkgs.coreutils}/bin/echo -n $RAM_75_PERCENT
        else
            ${pkgs.coreutils}/bin/echo -n $RAM_MINUS_6GB
        fi > $out
      ''
    );
    hostRamGb = let 
      vmRam = lib.toInt vmRamGb;
    in if vmRam > 18 then vmRam / 3 else 6;
    vmIds = builtins.fromJSON(
      builtins.readFile(
        pkgs.runCommand "vm-ids" {} ''
          #!${pkgs.bash}/bin/bash
          HASH1=$(${pkgs.coreutils}/bin/echo -n "${vmName}_1" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          HASH2=$(${pkgs.coreutils}/bin/echo -n "${vmName}_2" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          HASH3=$(${pkgs.coreutils}/bin/echo -n "${vmName}_3" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

          UUID=$(${pkgs.coreutils}/bin/echo $HASH1 | ${pkgs.coreutils}/bin/cut -c1-32 | ${pkgs.gnused}/bin/sed 's/\([0-9a-f]\{8\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{12\}\)/\1-\2-\3-\4-\5/')
          MAC1="52:54:00:$(${pkgs.coreutils}/bin/echo $HASH2 | ${pkgs.coreutils}/bin/cut -c1-6 | ${pkgs.gnused}/bin/sed 's/\(..\)/\1:/g' | ${pkgs.gnused}/bin/sed 's/:$//')"
          MAC2="52:54:01:$(${pkgs.coreutils}/bin/echo $HASH3 | ${pkgs.coreutils}/bin/cut -c1-6 | ${pkgs.gnused}/bin/sed 's/\(..\)/\1:/g' | ${pkgs.gnused}/bin/sed 's/:$//')"

          ${pkgs.coreutils}/bin/cat << EOF > $out
          {
            "UUID": "$UUID",
            "MAC1": "$MAC1",
            "MAC2": "$MAC2"
          }
          EOF
        ''
      )
    );
    vmPci = lib.custom.detectPci { inherit devices; };
    vmCpu = lib.custom.detectCpu { inherit cpu; };
    mkCdromXml = index: isoPath: ''
''\n    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw' io='native' cache='directsync'/>
      <source file='${isoPath}'/>
      <target dev='sd${builtins.substring (index + drivesCount) 1 "abcdefghijklmnopqrstuvwxyz"}' bus='sata'/>
      <readonly/>
    </disk>'';
    cdromXml = if ! (cdIso == null || cdIso == []) then
      builtins.concatStrings (lib.lists.imap0 mkCdromXml cdIso)
    else "";
  in {
    coreInfo = {
      hostCores = {
        list = vmCpu.reservedNoEmulatorList;
        count = vmCpu.hostReserveCount;
      };
      vmCores = {
        list = vmCpu.vmCoresList;
        mask = vmCpu.vmAffinityMask;
      };
    };
    ramGb = {
      vm = vmRamGb;
      host = hostRamGb;
    };
    params = lib.splitString "," vmPci.params;
    xml = if (vmPci ? error) then throw vmPci.error else pkgs.writeText "${vmName}.xml" ''
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>${vmName}</name>
  <uuid>${vmIds.UUID}</uuid>
  <title>${vmTitle}</title>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/11"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit='GiB'>${vmRamGb}</memory>
  <currentMemory unit='GiB'>${vmRamGb}</currentMemory>
  <memoryBacking>
    <hugepages/>
    <nosharepages/>
    <locked/>
  </memoryBacking>
  <iothreads>1</iothreads>${vmCpu.cpuXml}
  <os>
    <type arch='x86_64' machine='${machineVersion}'>hvm</type>
    <loader readonly='yes' type='pflash' format='raw'>${cfgFd}/OVMF_CODE.fd</loader>
    <nvram template='${cfgFd}/OVMF_VARS.fd' templateFormat="raw" format="raw">/vm_images/${vmName}/OVMF_VARS.fd</nvram>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
    <bootmenu enable='no'/>
    <smbios mode='host'/>
  </os>
  <features>
    <acpi/>
    <apic eoi="on"/>
    <hap state="on"/>
    <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="4095"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on">
        <direct state="on"/>
      </stimer>
      <reset state="on"/>
      <vendor_id state="on" value="KVM"/>
      <frequencies state="on"/>
      <reenlightenment state="off"/>
      <tlbflush state="on"/>
      <ipi state="on"/>
      <evmcs state="off"/>
      <avic state="on"/>
    </hyperv>
    <kvm>
      <hidden state="on"/>
      <hint-dedicated state="on"/>
    </kvm>
    <vmport state="off"/>
    <smm state="on"/>
    <ioapic driver="kvm"/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='off'>
    ${vmCpu.topologyXml}
    <cache mode='passthrough'/>
    <feature policy="require" name="topoext"/>
    <feature policy="require" name="invtsc"/>
    <feature policy="require" name="hypervisor"/>
    <feature policy="disable" name="svm"/>
    <feature policy="disable" name="x2apic"/>
  </cpu>
  <clock offset="localtime">
    <timer name="rtc" present="no" tickpolicy="catchup"/>
    <timer name="pit" present="no" tickpolicy="discard"/>
    <timer name="hpet" present="no"/>
    <timer name="kvmclock" present="no"/>
    <timer name="hypervclock" present="yes"/>
    <timer name="tsc" present="yes" mode="native"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>${qemu}</emulator>${drivesXml}${cdromXml}
    <controller type='scsi' index='0' model='virtio-scsi'>
      <driver queues='16' iothread='1' packed='on'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </controller>
    <interface type='network'>
      <mac address='${vmIds.MAC1}'/>
      <source network='host-guest'/>
      <model type='virtio'/>
      <driver queues='16'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <interface type='bridge'>
      <mac address='${vmIds.MAC2}'/>
      <source bridge='br0'/>
      <model type='virtio'/>
      <driver queues='2'/>
      <link state='up'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </interface>
    <watchdog model='itco' action='reset'/>
    <memballoon model='none'/>
    <panic model='hyperv'/>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </rng>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
${vmPci.xml}  </devices>
  <qemu:commandline>
    <qemu:arg value="-overcommit"/>
    <qemu:arg value="cpu-pm=on"/>
  </qemu:commandline>
</domain>'';
  };
}
