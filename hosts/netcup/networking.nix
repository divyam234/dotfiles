{ lib, ... }:
{
  # Keep this generic by default. Replace with your Netcup static networking
  # after checking the current VPS interface/address values.
  networking.useDHCP = lib.mkDefault true;
}
