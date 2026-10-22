{ pkgs ? import <nixpkgs> { }
, image ? "docker.io/library/ubuntu:latest"
, containerName ? "ubuntu"
, icon ? "distributor-logo-ubuntu"
}:

let
  inherit (pkgs) lib;

  script = pkgs.writeShellApplication {
    name = "mx-ubuntu-box";
    runtimeInputs = [
      pkgs.distrobox
      pkgs.podman
    ];
    text = ''
      export DBX_CONTAINER_MANAGER=podman

      name=${lib.escapeShellArg containerName}
      image=${lib.escapeShellArg image}

      fail() {
        printf '\n%s\n\n' "$1" >&2
        printf '%s' "Press Enter to close this window. " >&2
        read -r _ || true
        exit 1
      }

      if ! podman container exists "$name"; then
        printf '%s\n' "First launch: creating the '$name' container from $image."
        printf '%s\n' "This downloads a few hundred megabytes and takes a few minutes."
        printf '%s\n\n' "It happens only once - later launches open straight away."

        if ! podman pull "$image"; then
          fail "Could not download $image. Check the network connection and try again."
        fi

        if ! distrobox create --yes --no-entry \
          --image "$image" \
          --name "$name"; then
          fail "Could not create the '$name' container."
        fi
      fi

      exec distrobox enter "$name"
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "mx-ubuntu-box";
    desktopName = "Ubuntu container";
    genericName = "Development container";
    comment = "Open a shell in an Ubuntu container that shares your home directory";
    exec = "mx-ubuntu-box";
    inherit icon;
    terminal = true;
    categories = [ "Development" ];
    keywords = [
      "distrobox"
      "ubuntu"
      "container"
      "podman"
      "apt"
      "deb"
    ];
    extraConfig = {
      "Name[fr]" = "Conteneur Ubuntu";
      "Name[es]" = "Contenedor Ubuntu";
      "Name[de]" = "Ubuntu-Container";
      "GenericName[fr]" = "Conteneur de développement";
      "GenericName[es]" = "Contenedor de desarrollo";
      "GenericName[de]" = "Entwicklungscontainer";
      "Comment[fr]" = "Ouvrir un shell dans un conteneur Ubuntu qui partage votre dossier personnel";
      "Comment[es]" = "Abrir una terminal en un contenedor Ubuntu que comparte su carpeta personal";
      "Comment[de]" = "Eine Shell in einem Ubuntu-Container öffnen, der Ihr persönliches Verzeichnis teilt";
    };
  };
in
pkgs.symlinkJoin {
  name = "mx-ubuntu-box";
  paths = [
    script
    desktopItem
  ];
  meta.mainProgram = "mx-ubuntu-box";
}
