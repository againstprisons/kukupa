{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

with lib;

let
  neededLibraries = with pkgs; [
    curl
    libsodium
    libxml2
    libxslt
    postgresql
  ];

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    ruby
    bundler

    nodejs
    nodePackages.npm

    pkg-config
    shared-mime-info
  ] ++ neededLibraries;

  "LD_LIBRARY_PATH" = makeLibraryPath neededLibraries;
  "FREEDESKTOP_MIME_TYPES_PATH" = "${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml";
}