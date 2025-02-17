{pkgs}: let
  pypkgs = {python3Packages}:
    with python3Packages; [
      flake8
      pylint
      argcomplete
      requests
      setuptools
    ];
in
  pkgs.python312Packages.buildPythonApplication {
    name = "virtme-ng";
    src = pkgs.fetchgit {
      url = "https://github.com/arighi/virtme-ng.git";
      rev = "v1.32";
      hash = "sha256-tIAwJXsubQs8/Pr9OOuqFPFPa2T7xpAjU9NQo5Fcur4=";
    };

    buildInputs = pypkgs {python3Packages = pkgs.python312Packages;};

    propagatedBuildInputs = pypkgs {python3Packages = pkgs.python312Packages;};

    doCheck = false;
  }
