{ ... }:

{
  imports = let
    # Function to import all .nix files from a directory recursively
    importAll = dir:
      builtins.concatMap (name:
        let
          entries = builtins.readDir dir;
          entryType = entries.${name};
          fullPath = "${builtins.toString dir}/${name}";
        in
          if entryType == "directory" then
            importAll fullPath
          else if builtins.match ".*\\.nix$" name != null then
            [ fullPath ]
          else
            []
      ) (builtins.attrNames (builtins.readDir dir));
  in
    importAll ./modules;
}