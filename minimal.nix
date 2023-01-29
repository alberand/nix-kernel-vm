# Building with following command:
#   nix-build '<nixpkgs/nixos>' --arg configuration ./minimal.nix
{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  xfsprogs-overlay = (self: super: {
    xfsprogs = super.xfsprogs.overrideAttrs (prev: {
      version = "git";
      src = /home/alberand/Projects/xfsprogs-dev;
    });
  });
in
{
  imports = [ 
    (modulesPath + "/profiles/qemu-guest.nix") 
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  # Add packages to VM
  environment.systemPackages = with pkgs; [
        xfsprogs
  ];

  # Apply overlay on the package (use different src as we replaced 'src = ')
  nixpkgs.overlays = [ xfsprogs-overlay ];

  system.stateVersion = "22.11"; # Did you read the comment?
}
