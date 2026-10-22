{ pkgs ? import <nixpkgs> { }
, image ? "docker.io/library/ubuntu:26.04"
, installDir ? "$HOME/.local/share/ue5"
, nvidia ? false
, additionalPackages ? [ ]
, prefersDgpu ? false
}:

let
  inherit (pkgs) lib;

  distroboxApp = import ../lib/distrobox-app.nix { inherit pkgs lib; };

  criticalAptPackages = [
    "libglu1-mesa"
    "libgl1-mesa-dri"
    "libvulkan1"
    "mesa-vulkan-drivers"
    "libsdl2-2.0-0"
    "libx11-6"
    "libssl3"
    "ca-certificates"
  ];

  aptPackages = criticalAptPackages ++ [
    "libxcursor1"
    "libxrandr2"
    "libxinerama1"
    "libxi6"
    "libxext6"
    "libxfixes3"
    "libxss1"
    "libxcb1"
    "libxcomposite1"
    "libxdamage1"
    "libxkbcommon0"
    "libpulse0"
    "libasound2t64"
    "libudev1"
    "libfontconfig1"
    "libfreetype6"
    "libnss3"
    "libnspr4"
    "libatk1.0-0"
    "libatk-bridge2.0-0"
    "libcups2"
    "libdrm2"
    "libdbus-1-3"
    "libexpat1"
    "libpango-1.0-0"
    "libcairo2"
    "libgbm1"
    "libegl1"
    "openssl"
  ];

  app = distroboxApp.mkApp {
    name = "mx-ue5";
    displayName = "Unreal Engine 5";
    containerName = "distrobox-app-ue5";
    containerImage = image;
    inherit installDir nvidia;
    additionalContainerPkgs = additionalPackages;
    binaryRelPath = "Engine/Binaries/Linux/UnrealEditor";
    zipValidator = "Engine/";

    installSteps = [
      {
        labels = {
          en = "Extracting the Unreal Engine 5 archive…";
          fr = "Extraction de l'archive Unreal Engine 5…";
          es = "Extrayendo el archivo de Unreal Engine 5…";
          de = "Unreal-Engine-5-Archiv wird entpackt…";
        };
        percentage = true;
        script = ''
          mkdir -p "$INSTALL_DIR"

          entries=$(unzip -l "$ZIP_PATH" 2>/dev/null | tail -1 | awk '{print $2}')
          case "''${entries:-}" in ""|*[!0-9]*) entries=0 ;; esac

          unzip -o "$ZIP_PATH" -d "$INSTALL_DIR" | awk -v total="$entries" '
            /^ *(inflating|extracting|creating|linking|replacing):/ && total > 0 {
              n++
              p = int(n * 100 / total)
              if (p > 100) { p = 100 }
              if (p > last) { last = p; print p; fflush() }
            }
            END { print 100; fflush() }
          ' >&3

          if [ ! -d "$INSTALL_DIR/Engine" ]; then
            inner=""
            for d in "$INSTALL_DIR"/*/; do
              inner="''${d%/}"
              break
            done
            if [ -n "$inner" ] && [ -d "$inner/Engine" ]; then
              shopt -s dotglob
              mv "$inner"/* "$INSTALL_DIR"/
              shopt -u dotglob
              rmdir "$inner"
            fi
          fi
        '';
      }
      {
        labels = {
          en = "Installing system dependencies in the container…";
          fr = "Installation des dépendances système dans le conteneur…";
          es = "Instalando las dependencias del sistema en el contenedor…";
          de = "Systemabhängigkeiten werden im Container installiert…";
        };
        scope = "container";
        script = ''
          distrobox enter "$CONTAINER" -- true

          px() {
            podman exec --user root "$CONTAINER" \
              env DEBIAN_FRONTEND=noninteractive "$@"
          }

          px dpkg --configure -a || true
          px apt-get update -y -qq

          wanted=( ${lib.escapeShellArgs aptPackages} )

          icu=$(px apt-cache --names-only search '^libicu[0-9]+$' 2>/dev/null \
                  | awk '{print $1}' | sort -V | tail -1 || true)
          case "''${icu:-}" in
            libicu[0-9]*) wanted+=( "$icu" ) ;;
            *) echo "no versioned libicu package found; .NET tooling may refuse to start" ;;
          esac

          if ! px apt-get install -y -qq --no-install-recommends "''${wanted[@]}"; then
            echo "bulk install failed, retrying package by package"
            failed=""
            for p in "''${wanted[@]}"; do
              if ! px apt-get install -y -qq --no-install-recommends "$p"; then
                failed="$failed $p"
              fi
            done
            missing=""
            for p in ${lib.escapeShellArgs criticalAptPackages}; do
              case " $failed " in
                *" $p "*) missing="$missing $p" ;;
              esac
            done
            if [ -n "$missing" ]; then
              echo "critical packages missing:$missing"
              return 1
            fi
            if [ -n "$failed" ]; then
              echo "optional packages skipped:$failed"
            fi
          fi

          px apt-get clean
          px rm -rf /var/lib/apt/lists
        '';
      }
      {
        labels = {
          en = "Running the Unreal Engine 5 setup script…";
          fr = "Exécution du script d'installation d'Unreal Engine 5…";
          es = "Ejecutando el script de instalación de Unreal Engine 5…";
          de = "Unreal-Engine-5-Setup-Skript wird ausgeführt…";
        };
        guard = ''
          [ -f "$INSTALL_DIR/Setup.sh" ]
        '';
        script = ''
          chmod +x "$INSTALL_DIR/Setup.sh"
          # shellcheck disable=SC2016
          distrobox enter "$CONTAINER" -- \
            bash -c 'cd "$1" && ./Setup.sh' mx-ue5 "$INSTALL_DIR" < /dev/null
        '';
      }
    ];

    translations = {
      en = {
        t_welcome = "<b>Welcome to the Unreal Engine 5 installer</b>\n\nSelect the <b>.zip</b> archive downloaded from the Epic Games website (prebuilt Linux version).\n\n<a href=\"https://www.unrealengine.com/linux\">https://www.unrealengine.com/linux</a>\n\nDestination:";
        t_select_zip = "Select the Unreal Engine 5 archive (.zip)";
        t_done = "<b>Installation complete!</b>\n\nUnreal Engine 5 is ready.\nThe editor will now start.";
        t_binary_missing = "Extraction failed, or the archive contains no prebuilt Linux editor.\n\nDownload the <b>Linux</b> version from the Epic Games website.";
        t_uninstall_confirm = "This will permanently remove:\n\n  • the Unreal Engine 5 files\n  • the dedicated container <b>distrobox-app-ue5</b>\n\nAre you sure?";
        t_uninstalled = "<b>Unreal Engine 5 has been uninstalled.</b>\n\nThe container <b>distrobox-app-ue5</b> and the installed files have been removed.\n\nClick the icon again to reinstall.";
      };
      fr = {
        t_welcome = "<b>Bienvenue dans l'installateur d'Unreal Engine 5</b>\n\nChoisissez l'archive <b>.zip</b> téléchargée depuis le site Epic Games (version Linux précompilée).\n\n<a href=\"https://www.unrealengine.com/linux\">https://www.unrealengine.com/linux</a>\n\nDestination :";
        t_select_zip = "Choisissez l'archive Unreal Engine 5 (.zip)";
        t_done = "<b>Installation terminée !</b>\n\nUnreal Engine 5 est prêt.\nL'éditeur va démarrer.";
        t_binary_missing = "L'extraction a échoué, ou l'archive ne contient pas d'éditeur Linux précompilé.\n\nTéléchargez la version <b>Linux</b> depuis le site Epic Games.";
        t_uninstall_confirm = "Ceci supprimera définitivement :\n\n  • les fichiers d'Unreal Engine 5\n  • le conteneur dédié <b>distrobox-app-ue5</b>\n\nConfirmer ?";
        t_uninstalled = "<b>Unreal Engine 5 a été désinstallé.</b>\n\nLe conteneur <b>distrobox-app-ue5</b> et les fichiers installés ont été supprimés.\n\nCliquez de nouveau sur l'icône pour réinstaller.";
      };
      es = {
        t_welcome = "<b>Bienvenido al instalador de Unreal Engine 5</b>\n\nSeleccione el archivo <b>.zip</b> descargado del sitio de Epic Games (versión Linux precompilada).\n\n<a href=\"https://www.unrealengine.com/linux\">https://www.unrealengine.com/linux</a>\n\nDestino:";
        t_select_zip = "Seleccione el archivo de Unreal Engine 5 (.zip)";
        t_done = "<b>¡Instalación completada!</b>\n\nUnreal Engine 5 está listo.\nEl editor se iniciará ahora.";
        t_binary_missing = "La extracción ha fallado, o el archivo no contiene un editor Linux precompilado.\n\nDescargue la versión <b>Linux</b> desde el sitio de Epic Games.";
        t_uninstall_confirm = "Esto eliminará definitivamente:\n\n  • los archivos de Unreal Engine 5\n  • el contenedor dedicado <b>distrobox-app-ue5</b>\n\n¿Está seguro?";
        t_uninstalled = "<b>Unreal Engine 5 se ha desinstalado.</b>\n\nEl contenedor <b>distrobox-app-ue5</b> y los archivos instalados se han eliminado.\n\nVuelva a pulsar el icono para reinstalarlo.";
      };
      de = {
        t_welcome = "<b>Willkommen beim Unreal-Engine-5-Installationsprogramm</b>\n\nWählen Sie das von der Epic-Games-Website heruntergeladene <b>.zip</b>-Archiv aus (vorkompilierte Linux-Version).\n\n<a href=\"https://www.unrealengine.com/linux\">https://www.unrealengine.com/linux</a>\n\nZielordner:";
        t_select_zip = "Wählen Sie das Unreal-Engine-5-Archiv (.zip)";
        t_done = "<b>Installation abgeschlossen!</b>\n\nUnreal Engine 5 ist bereit.\nDer Editor wird jetzt gestartet.";
        t_binary_missing = "Das Entpacken ist fehlgeschlagen, oder das Archiv enthält keinen vorkompilierten Linux-Editor.\n\nLaden Sie die <b>Linux</b>-Version von der Epic-Games-Website herunter.";
        t_uninstall_confirm = "Damit wird endgültig entfernt:\n\n  • die Unreal-Engine-5-Dateien\n  • der zugehörige Container <b>distrobox-app-ue5</b>\n\nSind Sie sicher?";
        t_uninstalled = "<b>Unreal Engine 5 wurde deinstalliert.</b>\n\nDer Container <b>distrobox-app-ue5</b> und die installierten Dateien wurden entfernt.\n\nKlicken Sie erneut auf das Symbol, um es neu zu installieren.";
      };
    };
  };

  mimeType = pkgs.writeTextFile {
    name = "mx-ue5-mime";
    destination = "/share/mime/packages/mx-ue5.xml";
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
        <mime-type type="application/x-ue-project">
          <comment>Unreal Engine project</comment>
          <comment xml:lang="fr">Projet Unreal Engine</comment>
          <comment xml:lang="es">Proyecto de Unreal Engine</comment>
          <comment xml:lang="de">Unreal-Engine-Projekt</comment>
          <glob pattern="*.uproject"/>
        </mime-type>
      </mime-info>
    '';
  };

  desktopItem = pkgs.writeTextFile {
    name = "mx-ue5-desktop-item";
    destination = "/share/applications/mx-ue5.desktop";
    text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Unreal Engine 5
      GenericName=Game engine
      GenericName[fr]=Moteur de jeu
      GenericName[es]=Motor de juego
      GenericName[de]=Spiele-Engine
      Comment=Unreal Engine 5 editor, in a dedicated Ubuntu container
      Comment[fr]=Éditeur Unreal Engine 5, dans un conteneur Ubuntu dédié
      Comment[es]=Editor de Unreal Engine 5, en un contenedor Ubuntu dedicado
      Comment[de]=Unreal-Engine-5-Editor in einem eigenen Ubuntu-Container
      Exec=mx-ue5 %f
      Icon=ue4editor
      Terminal=false
      StartupNotify=true
      StartupWMClass=UnrealEditor
      Categories=Development;IDE;
      MimeType=application/x-ue-project;
      Keywords=unreal;ue5;gamedev;epic;
    '' + lib.optionalString prefersDgpu "PrefersNonDefaultGPU=true\n";
  };

in
pkgs.symlinkJoin {
  name = "mx-ue5";
  paths = app.packages ++ [
    mimeType
    desktopItem
  ];
  meta.mainProgram = "mx-ue5";
}
