{ pkgs, ... }:

let
  customPython = (
    ( let
        optPython = pkgs.python3.override {
          enableOptimizations = true;
          enableLTO = true;
          reproducibleBuild = false;
          self = optPython;
        };
      in optPython
    ).withPackages (pythonPackages: with pythonPackages; [
        vfio-isolate
      ]
    )
  );

  fixPackages = [
    (self: super: {
      numpy = super.numpy.overridePythonAttrs (old: {
        disabledTests = old.disabledTests ++ [
          "test_validate_transcendentals"
        ];
      });
    })
  ];
in
{
  environment.systemPackages = [ customPython ];

  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ fixPackages;
    })
  ];


}
