{ lib, ... } @ args:

let
  collectNix = dir:
    builtins.concatMap (name:
      let
        fullPath = "${dir}/${name}";
      in
        if (builtins.readDir dir).${name} == "directory"
        then collectNix fullPath
        else if builtins.match ".*\\.nix$" name != null
        then [ fullPath ]
        else [ ]
    ) (builtins.attrNames (builtins.readDir dir));
in
lib.fix (self:
  builtins.foldl' (acc: f: acc // (import f (args // { lib = lib // { custom = self; }; }))) { } (collectNix ./lib)
)
