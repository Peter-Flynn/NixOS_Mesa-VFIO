{ pkgs, lib, ... }:

let
  inherit (builtins) fromJSON readFile currentTime toString;
  inherit (pkgs) runCommand gawk;
in {
  detectCpu = with lib; { cpu ? {} }: let
    # ── Walk full host topology from /sys ─────────────────────────────────
    cpuInfo = fromJSON (readFile (
      runCommand "cpu-info" {
        preferLocalBuild = true;
        allowSubstitutes = false;
        time = currentTime;
      } ''
        shopt -s nullglob
        ${gawk}/bin/awk '
          { match(FILENAME, /cpu([0-9]+)\//, M); c = M[1] }
          FILENAME ~ /physical_package_id/  { pkg[c] = $0 }
          FILENAME ~ /die_id/               { die[c] = $0 }
          FILENAME ~ /thread_siblings_list/ { sib[c] = $0 }
          FILENAME ~ /shared_cpu_list/      { l3[c]  = $0 }
          END {
            for (c in sib) { N++; cg[sib[c]] = 1 }     # distinct cores
            for (g in cg)  totalCores++
            threads = N / totalCores

            for (c in pkg) sk[pkg[c]] = 1               # distinct sockets
            for (s in sk)  sockets++

            for (c in pkg) dk[pkg[c] SUBSEP die[c]] = 1 # distinct dies
            for (k in dk)  totalDies++

            for (c in l3)  lk[l3[c]] = 1                # distinct CCXes
            for (g in lk)  totalClusters++

            printf "{\"sockets\":%d,\"dies\":%d,\"clusters\":%d,\"coresPerCluster\":%d,\"threads\":%d,\"logical\":%d}\n", \
              sockets, totalDies/sockets, totalClusters/totalDies, \
              totalCores/totalClusters, threads, N
          }
        ' /sys/devices/system/cpu/cpu*/topology/physical_package_id \
          /sys/devices/system/cpu/cpu*/topology/die_id \
          /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
          /sys/devices/system/cpu/cpu*/cache/index3/shared_cpu_list > $out
      ''
    ));

    sockets        = cpuInfo.sockets;
    dies           = cpuInfo.dies;
    clusters       = cpuInfo.clusters;
    ccxSize        = cpuInfo.coresPerCluster;
    threadsPerCore = cpuInfo.threads;
    cores          = sockets * dies * clusters * ccxSize;  # total physical cores

    # ── Reserve / pin math (UNCHANGED) ────────────────────────────────────
    reserve      = if cores > cpu.hugeThreshold then ccxSize else cpu.hostReserve;
    totalVcpus   = cores * threadsPerCore;
    enabledVcpus = totalVcpus - threadsPerCore * reserve;
    emulatorCore = reserve - 1;

    smtSibling = c: t: c + t * cores;
    siblingsList = c:
      concatMapStringsSep ","
        (t: toString (smtSibling c t))
        (range 0 (threadsPerCore - 1));

    emulatorPin = siblingsList emulatorCore;
    tpcR        = threadsPerCore * reserve;

    vcpusXml = concatStrings (genList (i: ''
''\n    <vcpu id="${toString i}" enabled="${if i >= tpcR && i < 2 * tpcR then "no" else "yes"}" hotpluggable="${if i < tpcR then "no" else "yes"}"/>''
    ) totalVcpus);

    vcpupinXml = concatStrings (genList (k:
      let
        hostCore = if k < reserve then reserve + k else k;
      in
      if k >= reserve && k < 2 * reserve then ""
      else concatMapStrings (t:
        "\n    <vcpupin vcpu='${toString (threadsPerCore * k + t)}' cpuset='${toString (smtSibling hostCore t)}'/>"
      ) (range 0 (threadsPerCore - 1))
    ) cores);

    # ── Extra core-set outputs ────────────────────────────────────────────
    # Logical CPUs of a contiguous physical span [lo,hi], grouped per SMT
    # thread → range-list. coreRange 0 2 (2 threads, 32 cores) = "0-2,32-34".
    coreRange = lo: hi:
      concatMapStringsSep ","
        (t: let a = lo + t * cores; b = hi + t * cores;
            in if a == b then toString a else "${toString a}-${toString b}")
        (range 0 (threadsPerCore - 1));

    # Host-reserved cores, minus the emulator core (= the last reserved core).
    reservedNoEmulatorList =
      if reserve <= 1 then coreRange 0 0 else coreRange 0 (reserve - 2);

    # Every core the VM touches, including the emulator core.
    vmCoresList = coreRange (reserve - 1) (cores - 1);

    # Single smp_affinity mask: all VM CPUs set, host-reserved + emulator
    # cleared. Comma-separated 32-bit hex words, MSB-first, not zero-filled.
    toHex = let
      go = n: if n == 0 then ""
              else go (n / 16) + builtins.substring (mod n 16) 1 "0123456789abcdef";
    in n: if n == 0 then "0" else go n;
    pow2 = k: foldl' (a: _: a * 2) 1 (range 1 k);
    vmCpus = concatMap
      (t: map (c: c + t * cores) (range reserve (cores - 1)))
      (range 0 (threadsPerCore - 1));
    wordValue = j: foldl'
      (acc: cpu: if cpu >= 32 * j && cpu < 32 * (j + 1)
                 then acc + pow2 (cpu - 32 * j) else acc)
      0 vmCpus;
    nWords = (totalVcpus - 1) / 32 + 1;
    vmAffinityMask = concatMapStringsSep ","
      (i: toHex (wordValue (nWords - 1 - i)))
      (range 0 (nWords - 1));

    # ── Public XML ────────────────────────────────────────────────────────
    cpuXml = ''
''\n  <vcpu placement='static' current='${toString enabledVcpus}'>${toString totalVcpus}</vcpu>
  <vcpus>${vcpusXml}
  </vcpus>
  <cputune>${vcpupinXml}
    <emulatorpin cpuset='${emulatorPin}'/>
    <vcpusched vcpus='0-${toString (totalVcpus - 1)}' scheduler='rr' priority='1'/>
    <iothreadpin iothread='1' cpuset='${emulatorPin}'/>
    <emulatorsched scheduler='rr' priority='1'/>
    <iothreadsched iothreads='1' scheduler='fifo' priority='98'/>
  </cputune>'';
    topologyXml = "<topology sockets='${toString sockets}' dies='${toString dies}' clusters='${toString clusters}' cores='${toString ccxSize}' threads='${toString threadsPerCore}'/>";
  in
  assert assertMsg
    (sockets * dies * clusters * ccxSize * threadsPerCore == cpuInfo.logical)
    "cpu-topology: ${toString sockets}×${toString dies}×${toString clusters}×${toString ccxSize}×${toString threadsPerCore} ≠ ${toString cpuInfo.logical} logical CPUs — asymmetric/partial-CCX layout can't be mirrored in libvirt <topology>.";
  {
    inherit sockets dies clusters ccxSize threadsPerCore cores
            reserve totalVcpus enabledVcpus emulatorPin
            cpuXml topologyXml
            reservedNoEmulatorList vmCoresList vmAffinityMask;
  };
}