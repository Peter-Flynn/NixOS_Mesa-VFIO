{ pkgs, ... }:

let
  packageDef = python-self: python-super: {
    vfio-isolate = python-self.buildPythonPackage {
      pname = "vfio-isolate";
      version = "0.5.1";
      pyproject = true;

      src = builtins.fetchGit {
          url = "https://github.com/spheenik/vfio-isolate";
          rev = "c6eb01cab509dfa6a220dc17f44233fa4e93493c";
          shallow = true;
        };

      build-system = with python-self; [ setuptools ];

      propagatedBuildInputs = with python-self; [ click psutil ];

      doCheck = false;

      meta = with pkgs.lib; {
        description = "Commandline tool to facilitate CPU core isolation";
        homepage = "https://github.com/spheenik/vfio-isolate";
        license = licenses.bsd3;
      };
    };
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ packageDef ];
    })
  ];
}
