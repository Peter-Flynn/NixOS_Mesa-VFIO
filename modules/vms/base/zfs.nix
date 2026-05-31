{ ... }:

{
  boot.kernelParams = [
    "zfs.zfs_arc_shrink_shift=3"      # Shrink faster
    "zfs.l2arc_meta_percent=95"       # 95% of ARC for L2ARC metadata
  ];
}
