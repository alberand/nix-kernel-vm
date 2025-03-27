{
  description = "PowerStick dev env";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      {
        devShells.default = with pkgs; mkShell rec {
          buildInputs = [
            openssl
            pkg-config
            eza
            fd
            (rust-bin.selectLatestNightlyWith (toolchain: toolchain.default))
            # WINIT_UNIX_BACKEND=wayland
            wayland

            libxkbcommon
            libGL

            # WINIT_UNIX_BACKEND=x11
            # xorg.libXcursor
            # xorg.libXrandr
            # xorg.libXi
            # xorg.libX11
          ];

          LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
          WINIT_UNIX_BACKEND = "wayland";

          shellHook = ''
            alias ls=eza
            alias find=fd
          '';
        };
      }
    );
}
