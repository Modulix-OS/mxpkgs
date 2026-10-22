# distrobox-app.nix
#
# Generic library: mkApp builds a Zenity + distrobox launcher for any
# application installed from a .zip archive the user supplies.
#
# The launcher is always present (before and after install) and doubles as
# a management UI: launch, reinstall, uninstall.
# Each app gets its own dedicated distrobox container.
#
# Returns: { launcher, enterScript, packages }

{ pkgs, lib }:

let
  genericKeys = [
    "t_no_display"
    "t_already_running"
    "t_podman_missing"
    "t_pull"
    "t_pull_failed"
    "t_create"
    "t_create_failed"
    "t_welcome"
    "t_select_zip"
    "t_filter_zip"
    "t_filter_all"
    "t_cancelled"
    "t_file_not_found"
    "t_not_an_archive"
    "t_cleaning"
    "t_no_space"
    "t_step_failed"
    "t_see_log"
    "t_binary_missing"
    "t_done"
    "t_path_outside_home"
    "t_menu_text"
    "t_menu_column"
    "t_menu_launch"
    "t_menu_reinstall"
    "t_menu_uninstall"
    "t_reinstall_confirm"
    "t_uninstall_confirm"
    "t_removing_container"
    "t_removing_image"
    "t_removing_files"
    "t_uninstalled"
    "t_unsafe_dir"
  ];

  mkDefaults = displayName: {
    en = {
      t_no_display = "needs a graphical session (neither DISPLAY nor WAYLAND_DISPLAY is set).";
      t_already_running = "Another ${displayName} installer window is already open.";
      t_podman_missing = "Podman is not available on this system.\n\nEnable the Ubuntu container module and try again.";
      t_pull = "Downloading the container image…\n<small>This happens only once and may take a few minutes.</small>";
      t_pull_failed = "Could not download the container image.\n\nCheck the network connection and try again.";
      t_create = "Setting up the container…";
      t_create_failed = "Could not create the container.";
      t_welcome = "<b>Welcome to the ${displayName} installer</b>\n\nSelect the <b>.zip</b> archive to install.";
      t_select_zip = "Select the ${displayName} archive (.zip)";
      t_filter_zip = "ZIP archives";
      t_filter_all = "All files";
      t_cancelled = "Installation cancelled.";
      t_file_not_found = "File not found:";
      t_not_an_archive = "This file does not look like a ${displayName} archive.\n\nContinue anyway?";
      t_cleaning = "Removing the previous installation…";
      t_no_space = "Not enough free space in the installation directory.\n\nRequired / available:";
      t_step_failed = "This installation step failed:";
      t_see_log = "Details:";
      t_binary_missing = "Installation failed: the program was not found after extraction.";
      t_done = "<b>Installation complete!</b>\n\n${displayName} is ready.";
      t_path_outside_home = "This file sits outside the home directory, the only one the container shares with the host. ${displayName} may not be able to open it.\n\nContinue anyway?";
      t_menu_text = "What would you like to do?";
      t_menu_column = "Action";
      t_menu_launch = "Launch ${displayName}";
      t_menu_reinstall = "Reinstall ${displayName} from an archive";
      t_menu_uninstall = "Uninstall ${displayName}";
      t_reinstall_confirm = "This will delete the installed ${displayName} files and extract a new archive in their place.\n\nThe container is kept.\n\nAre you sure?";
      t_uninstall_confirm = "This will permanently remove ${displayName} and its dedicated container.\n\nAre you sure?";
      t_removing_container = "Removing the container…";
      t_removing_image = "Removing the container image…";
      t_removing_files = "Removing the installed files…";
      t_uninstalled = "<b>${displayName} has been uninstalled.</b>\n\nClick the icon again to reinstall.";
      t_unsafe_dir = "Refusing to delete this installation directory:";
    };

    fr = {
      t_no_display = "nécessite une session graphique (ni DISPLAY ni WAYLAND_DISPLAY n'est défini).";
      t_already_running = "Une autre fenêtre de l'installateur de ${displayName} est déjà ouverte.";
      t_podman_missing = "Podman n'est pas disponible sur ce système.\n\nActivez le module de conteneur Ubuntu puis réessayez.";
      t_pull = "Téléchargement de l'image du conteneur…\n<small>Cela n'arrive qu'une fois et peut prendre quelques minutes.</small>";
      t_pull_failed = "Impossible de télécharger l'image du conteneur.\n\nVérifiez la connexion réseau puis réessayez.";
      t_create = "Préparation du conteneur…";
      t_create_failed = "Impossible de créer le conteneur.";
      t_welcome = "<b>Bienvenue dans l'installateur de ${displayName}</b>\n\nChoisissez l'archive <b>.zip</b> à installer.";
      t_select_zip = "Choisissez l'archive ${displayName} (.zip)";
      t_filter_zip = "Archives ZIP";
      t_filter_all = "Tous les fichiers";
      t_cancelled = "Installation annulée.";
      t_file_not_found = "Fichier introuvable :";
      t_not_an_archive = "Ce fichier ne ressemble pas à une archive ${displayName}.\n\nContinuer quand même ?";
      t_cleaning = "Suppression de l'installation précédente…";
      t_no_space = "Espace disque insuffisant dans le dossier d'installation.\n\nNécessaire / disponible :";
      t_step_failed = "Cette étape de l'installation a échoué :";
      t_see_log = "Détails :";
      t_binary_missing = "Installation échouée : le programme est introuvable après extraction.";
      t_done = "<b>Installation terminée !</b>\n\n${displayName} est prêt.";
      t_path_outside_home = "Ce fichier se trouve en dehors du dossier personnel, le seul que le conteneur partage avec l'hôte. ${displayName} ne pourra peut-être pas l'ouvrir.\n\nContinuer quand même ?";
      t_menu_text = "Que voulez-vous faire ?";
      t_menu_column = "Action";
      t_menu_launch = "Lancer ${displayName}";
      t_menu_reinstall = "Réinstaller ${displayName} depuis une archive";
      t_menu_uninstall = "Désinstaller ${displayName}";
      t_reinstall_confirm = "Ceci supprimera les fichiers installés de ${displayName} et extraira une nouvelle archive à leur place.\n\nLe conteneur est conservé.\n\nConfirmer ?";
      t_uninstall_confirm = "Ceci supprimera définitivement ${displayName} et son conteneur dédié.\n\nConfirmer ?";
      t_removing_container = "Suppression du conteneur…";
      t_removing_image = "Suppression de l'image du conteneur…";
      t_removing_files = "Suppression des fichiers installés…";
      t_uninstalled = "<b>${displayName} a été désinstallé.</b>\n\nCliquez de nouveau sur l'icône pour réinstaller.";
      t_unsafe_dir = "Suppression refusée pour ce dossier d'installation :";
    };

    es = {
      t_no_display = "necesita una sesión gráfica (ni DISPLAY ni WAYLAND_DISPLAY están definidos).";
      t_already_running = "Ya hay abierta otra ventana del instalador de ${displayName}.";
      t_podman_missing = "Podman no está disponible en este sistema.\n\nActive el módulo de contenedor Ubuntu e inténtelo de nuevo.";
      t_pull = "Descargando la imagen del contenedor…\n<small>Solo ocurre una vez y puede tardar unos minutos.</small>";
      t_pull_failed = "No se pudo descargar la imagen del contenedor.\n\nCompruebe la conexión de red e inténtelo de nuevo.";
      t_create = "Preparando el contenedor…";
      t_create_failed = "No se pudo crear el contenedor.";
      t_welcome = "<b>Bienvenido al instalador de ${displayName}</b>\n\nSeleccione el archivo <b>.zip</b> que desea instalar.";
      t_select_zip = "Seleccione el archivo ${displayName} (.zip)";
      t_filter_zip = "Archivos ZIP";
      t_filter_all = "Todos los archivos";
      t_cancelled = "Instalación cancelada.";
      t_file_not_found = "Archivo no encontrado:";
      t_not_an_archive = "Este archivo no parece un archivo de ${displayName}.\n\n¿Continuar de todos modos?";
      t_cleaning = "Eliminando la instalación anterior…";
      t_no_space = "No hay suficiente espacio libre en la carpeta de instalación.\n\nNecesario / disponible:";
      t_step_failed = "Este paso de la instalación ha fallado:";
      t_see_log = "Detalles:";
      t_binary_missing = "La instalación ha fallado: no se encuentra el programa tras la extracción.";
      t_done = "<b>¡Instalación completada!</b>\n\n${displayName} está listo.";
      t_path_outside_home = "Este archivo está fuera de la carpeta personal, la única que el contenedor comparte con el anfitrión. Puede que ${displayName} no consiga abrirlo.\n\n¿Continuar de todos modos?";
      t_menu_text = "¿Qué desea hacer?";
      t_menu_column = "Acción";
      t_menu_launch = "Iniciar ${displayName}";
      t_menu_reinstall = "Reinstalar ${displayName} desde un archivo";
      t_menu_uninstall = "Desinstalar ${displayName}";
      t_reinstall_confirm = "Esto eliminará los archivos instalados de ${displayName} y extraerá un archivo nuevo en su lugar.\n\nEl contenedor se conserva.\n\n¿Está seguro?";
      t_uninstall_confirm = "Esto eliminará definitivamente ${displayName} y su contenedor dedicado.\n\n¿Está seguro?";
      t_removing_container = "Eliminando el contenedor…";
      t_removing_image = "Eliminando la imagen del contenedor…";
      t_removing_files = "Eliminando los archivos instalados…";
      t_uninstalled = "<b>${displayName} se ha desinstalado.</b>\n\nVuelva a pulsar el icono para reinstalarlo.";
      t_unsafe_dir = "Se rechaza borrar esta carpeta de instalación:";
    };

    de = {
      t_no_display = "benötigt eine grafische Sitzung (weder DISPLAY noch WAYLAND_DISPLAY ist gesetzt).";
      t_already_running = "Es ist bereits ein weiteres ${displayName}-Installationsfenster geöffnet.";
      t_podman_missing = "Podman ist auf diesem System nicht verfügbar.\n\nAktivieren Sie das Ubuntu-Container-Modul und versuchen Sie es erneut.";
      t_pull = "Container-Abbild wird heruntergeladen…\n<small>Das geschieht nur einmal und kann einige Minuten dauern.</small>";
      t_pull_failed = "Das Container-Abbild konnte nicht heruntergeladen werden.\n\nPrüfen Sie die Netzwerkverbindung und versuchen Sie es erneut.";
      t_create = "Container wird eingerichtet…";
      t_create_failed = "Der Container konnte nicht erstellt werden.";
      t_welcome = "<b>Willkommen beim ${displayName}-Installationsprogramm</b>\n\nWählen Sie das zu installierende <b>.zip</b>-Archiv aus.";
      t_select_zip = "Wählen Sie das ${displayName}-Archiv (.zip)";
      t_filter_zip = "ZIP-Archive";
      t_filter_all = "Alle Dateien";
      t_cancelled = "Installation abgebrochen.";
      t_file_not_found = "Datei nicht gefunden:";
      t_not_an_archive = "Diese Datei sieht nicht nach einem ${displayName}-Archiv aus.\n\nTrotzdem fortfahren?";
      t_cleaning = "Vorherige Installation wird entfernt…";
      t_no_space = "Nicht genügend freier Speicherplatz im Installationsordner.\n\nBenötigt / verfügbar:";
      t_step_failed = "Dieser Installationsschritt ist fehlgeschlagen:";
      t_see_log = "Details:";
      t_binary_missing = "Installation fehlgeschlagen: Das Programm wurde nach dem Entpacken nicht gefunden.";
      t_done = "<b>Installation abgeschlossen!</b>\n\n${displayName} ist bereit.";
      t_path_outside_home = "Diese Datei liegt außerhalb des persönlichen Ordners, den der Container als einzigen mit dem Host teilt. ${displayName} kann sie möglicherweise nicht öffnen.\n\nTrotzdem fortfahren?";
      t_menu_text = "Was möchten Sie tun?";
      t_menu_column = "Aktion";
      t_menu_launch = "${displayName} starten";
      t_menu_reinstall = "${displayName} aus einem Archiv neu installieren";
      t_menu_uninstall = "${displayName} deinstallieren";
      t_reinstall_confirm = "Damit werden die installierten ${displayName}-Dateien gelöscht und ein neues Archiv an ihrer Stelle entpackt.\n\nDer Container bleibt erhalten.\n\nSind Sie sicher?";
      t_uninstall_confirm = "Damit werden ${displayName} und der zugehörige Container endgültig entfernt.\n\nSind Sie sicher?";
      t_removing_container = "Container wird entfernt…";
      t_removing_image = "Container-Abbild wird entfernt…";
      t_removing_files = "Installierte Dateien werden entfernt…";
      t_uninstalled = "<b>${displayName} wurde deinstalliert.</b>\n\nKlicken Sie erneut auf das Symbol, um es neu zu installieren.";
      t_unsafe_dir = "Das Löschen dieses Installationsordners wird verweigert:";
    };
  };

  mkCase = pattern: strings: ''
    ${pattern})
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (n: v: "  ${n}=${lib.escapeShellArg v}") strings
    )}
      ;;
  '';

in
{
  # ─────────────────────────────────────────────────────────────────────────
  # mkApp
  #
  # Required parameters:
  #   name              str       launcher command name (e.g. "mx-ue5")
  #   displayName       str       name shown in popups (e.g. "Unreal Engine 5")
  #   containerImage    str       fully qualified OCI image name, e.g.
  #                               "docker.io/library/ubuntu:22.04"
  #   installDir        str       installation directory, expanded by bash so
  #                               it may contain $HOME
  #   binaryRelPath     str       path to the executable relative to installDir
  #   installSteps      list of { labels: { en, fr, es, de }, script: str,
  #                               scope ? "archive" | "container",
  #                               guard ? str, percentage ? bool }
  #                               steps run sequentially on first launch; the
  #                               container-scoped ones also run on their own
  #                               when the container is missing or was built
  #                               from another image;
  #                               $INSTALL_DIR, $CONTAINER, $ZIP_PATH are exported;
  #                               stdout and stderr of a step go to the install
  #                               log, never to the screen;
  #                               guard is a test run before the step, which is
  #                               skipped silently when the test fails;
  #                               percentage makes the progress window
  #                               determinate, the step then writing 0..100 on
  #                               file descriptor 3
  #
  # Optional parameters:
  #   containerName             derived  name of the dedicated container
  #   environment               {}       variables prepended to the binary via env
  #   nvidia                    false    pass --nvidia to distrobox create
  #   init                      false    pass --init to distrobox create (only for
  #                                      images that ship an init system)
  #   additionalContainerPkgs   []       packages passed to --additional-packages
  #   zipValidator              null     grep pattern in `unzip -l` to validate zip
  #   spareSpace                bytes    free space required on top of the
  #                                      archive's uncompressed size
  #   extraRuntimeInputs        []       extra packages on the launcher's PATH
  #   translations              {}       per-language overrides of the UI strings
  # ─────────────────────────────────────────────────────────────────────────
  mkApp =
    { name
    , displayName
    , containerImage
    , installDir
    , binaryRelPath
    , installSteps
    , containerName           ? "distrobox-app-${name}"
    , environment             ? { }
    , nvidia                  ? false
    , init                    ? false
    , additionalContainerPkgs ? [ ]
    , zipValidator            ? null
    , spareSpace              ? 5368709120
    , extraRuntimeInputs      ? [ ]
    , translations            ? { }
    }:

    let
      langs = [ "en" "fr" "es" "de" ];
      defaults = mkDefaults displayName;

      stepLabels = lang:
        lib.listToAttrs (
          lib.imap0
            (i: step: lib.nameValuePair "t_step_${toString i}" step.labels.${lang})
            installSteps
        );

      unusedKeys = lib.optionals (zipValidator == null) [ "t_not_an_archive" ];

      activeKeys = lib.subtractLists unusedKeys genericKeys;

      merged = lib.listToAttrs (
        map
          (lang: lib.nameValuePair lang (
            lib.removeAttrs
              (defaults.${lang} // (translations.${lang} or { }) // stepLabels lang)
              unusedKeys
          ))
          langs
      );

      keysComplete =
        let
          ref = lib.sort (a: b: a < b) (
            activeKeys ++ lib.attrNames (stepLabels "en")
          );
        in
        lib.all (t: lib.sort (a: b: a < b) (lib.attrNames t) == ref) (lib.attrValues merged);

      langCase = ''
        case "$lang" in
        ${mkCase "fr" merged.fr}
        ${mkCase "es" merged.es}
        ${mkCase "de" merged.de}
        ${mkCase "*" merged.en}
        esac
      '';

      envPrefix = lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] name);

      envArgs = lib.escapeShellArgs (
        lib.mapAttrsToList (k: v: "${k}=${toString v}") environment
      );

      createFlags = lib.escapeShellArgs (
        [ "--yes" "--no-entry" "--image" containerImage "--name" containerName ]
        ++ lib.optional nvidia "--nvidia"
        ++ lib.optional init "--init"
        ++ lib.optionals
          (additionalContainerPkgs != [ ])
          [ "--additional-packages" (lib.concatStringsSep " " additionalContainerPkgs) ]
      );

      stepFunctions = lib.concatStrings (
        lib.imap0
          (i: step: ''
            step_${toString i}() {
            ${step.script}
            }

          '' + lib.optionalString ((step.guard or null) != null) ''
            guard_${toString i}() {
            ${step.guard}
            }

          '')
          installSteps
      );

      mkStepCall = i: step:
        let
          runner = if (step.percentage or false) then "pulse_pct" else "pulse";
          call = ''
            if ! ${runner} "$t_step_${toString i}" step_${toString i}; then
              zerror "$t_step_failed"$'\n\n'"$t_step_${toString i}"$'\n\n'"<small>$t_see_log <tt>$LOG_FILE</tt></small>"
              exit 1
            fi
          '';
        in
        if (step.guard or null) == null then call
        else ''
          if guard_${toString i} >>"$LOG_FILE" 2>&1; then
          ${call}
          fi
        '';

      stepCalls = lib.concatStrings (lib.imap0 mkStepCall installSteps);

      containerStepCalls = lib.concatStrings (
        lib.imap0
          (i: step: lib.optionalString ((step.scope or "archive") == "container") (mkStepCall i step))
          installSteps
      );

      zipValidation = lib.optionalString (zipValidator != null) ''
        zip_contains() (
          set +o pipefail
          unzip -l "$1" 2>/dev/null | grep -q -- "$2"
        )

        if ! zip_contains "$ZIP_PATH" ${lib.escapeShellArg zipValidator}; then
          zask "$t_not_an_archive" || exit 0
        fi
      '';

      helpText = ''
        ${name} - install, launch and manage ${displayName} in a dedicated container

        Usage: ${name} [FILE]

        With no argument the launcher opens the install wizard on first run, and a
        Launch / Reinstall / Uninstall menu afterwards. With a FILE argument it opens
        that file directly in ${displayName}.

        Every installation step writes its output to
          ~/.local/state/${name}/install.log, or under XDG_STATE_HOME when it is set.

        Environment:
          ${envPrefix}_LANG    force the interface language (en, fr, es, de)
      '';

      launcher = pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [
          pkgs.distrobox
          pkgs.podman
          pkgs.zenity
          pkgs.unzip
          pkgs.gnugrep
          pkgs.gawk
          pkgs.util-linux
          pkgs.coreutils
        ] ++ extraRuntimeInputs;
        text = ''
          RED='\033[0;31m'
          NC='\033[0m'

          case "''${1:-}" in
            -h|--help)
              printf '%s' ${lib.escapeShellArg helpText}
              exit 0
              ;;
          esac

          lang=''${${envPrefix}_LANG:-''${LC_ALL:-''${LC_MESSAGES:-''${LANG:-en}}}}
          lang=''${lang%%.*}
          lang=''${lang%%@*}
          lang=''${lang%%_*}
          lang=''${lang,,}

          ${langCase}

          if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
            printf '%b\n' "''${RED}${name}''${NC}: $t_no_display" >&2
            exit 1
          fi

          export DBX_CONTAINER_MANAGER=podman

          _TITLE=${lib.escapeShellArg displayName}
          _IMAGE=${lib.escapeShellArg containerImage}

          export CONTAINER=${lib.escapeShellArg containerName}
          export INSTALL_DIR="${installDir}"
          export ZIP_PATH=""
          BINARY="$INSTALL_DIR/${binaryRelPath}"
          SENTINEL="$INSTALL_DIR/.${name}-installed"
          IMAGE_STAMP="$INSTALL_DIR/.${name}-image"
          INCOMPLETE="$INSTALL_DIR/.${name}-incomplete"

          STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/${name}"
          LOG_FILE="$STATE_DIR/install.log"
          mkdir -p "$STATE_DIR"
          if [ "$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
            : > "$LOG_FILE"
          fi
          printf '\n==== %s ${name} ====\n' "$(date -Is)" >> "$LOG_FILE"

          zinfo()  { zenity --info     --title="$_TITLE" --text="$1" --width=460 2>/dev/null || true; }
          zerror() { zenity --error    --title="$_TITLE" --text="$1" --width=460 2>/dev/null || true; }
          zask()   { zenity --question --title="$_TITLE" --text="$1" --width=460 2>/dev/null; }

          exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/${name}.lock"
          if ! flock -n 9; then
            zerror "$t_already_running"
            exit 1
          fi

          rc_file=$(mktemp)
          trap 'rm -f "$rc_file"' EXIT

          with_progress() {
            local mode=$1 text=$2
            shift 2
            local -a zflags=(--pulsate)
            if [ "$mode" = pct ]; then
              zflags=(--percentage=0)
            fi
            : > "$rc_file"
            {
              (
                local rc
                if "$@" 3>&1 1>>"$LOG_FILE" 2>&1; then
                  rc=0
                else
                  rc=$?
                fi
                echo "$rc" > "$rc_file"
              ) | zenity --progress --title="$_TITLE" --text="$text" \
                    "''${zflags[@]}" --auto-close --no-cancel --width=500 >/dev/null 2>&1
            } || true
            [ "$(cat "$rc_file")" = "0" ]
          }

          pulse()     { with_progress pulsate "$@"; }
          pulse_pct() { with_progress pct "$@"; }

          ${stepFunctions}
          require_podman() {
            if ! podman info >/dev/null 2>&1; then
              zerror "$t_podman_missing"
              exit 1
            fi
          }

          stamped_ref=""
          stamped_id=""

          read_stamp() {
            stamped_ref=""
            stamped_id=""
            if [ -f "$IMAGE_STAMP" ]; then
              {
                read -r stamped_ref || true
                read -r stamped_id || true
              } < "$IMAGE_STAMP"
            fi
          }

          write_stamp() {
            local id
            id=$(podman image inspect --format '{{.Id}}' "$_IMAGE" 2>/dev/null || true)
            mkdir -p "$INSTALL_DIR"
            printf '%s\n%s\n' "$_IMAGE" "$id" > "$IMAGE_STAMP"
          }

          drop_image() {
            local ref=$1 id=$2
            if [ -n "$id" ]; then
              podman rmi "$id" >/dev/null 2>&1 || true
            elif [ -n "$ref" ]; then
              podman rmi "$ref" >/dev/null 2>&1 || true
            fi
          }

          container_ready() {
            podman container exists "$CONTAINER" || return 1
            read_stamp
            [ "$stamped_ref" = "$_IMAGE" ] || return 1
          }

          create_container() {
            read_stamp
            local previous_ref=$stamped_ref
            local previous_id=$stamped_id

            if podman container exists "$CONTAINER"; then
              pulse "$t_removing_container" distrobox rm --force "$CONTAINER" || true
            fi
            if ! pulse "$t_pull"$'\n\n'"<tt>$_IMAGE</tt>" podman pull "$_IMAGE"; then
              zerror "$t_pull_failed"
              exit 1
            fi
            if ! pulse "$t_create" distrobox create ${createFlags}; then
              zerror "$t_create_failed"
              exit 1
            fi

            write_stamp
            read_stamp

            if [ "$previous_ref" != "$_IMAGE" ] || [ "$previous_id" != "$stamped_id" ]; then
              drop_image "$previous_ref" "$previous_id"
            fi
          }

          rebuild_container() {
            create_container
            ${containerStepCalls}
          }

          safe_install_dir() {
            case "$INSTALL_DIR" in
              ""|"/"|"$HOME"|"$HOME"/) return 1 ;;
              /*) return 0 ;;
              *) return 1 ;;
            esac
          }

          install_dir_payload() {
            local f
            if [ ! -d "$INSTALL_DIR" ]; then
              return 1
            fi
            for f in "$INSTALL_DIR"/*; do
              if [ -e "$f" ]; then
                return 0
              fi
            done
            return 1
          }

          clean_install_dir() {
            local f
            for f in "$INSTALL_DIR"/*; do
              if [ -e "$f" ]; then
                rm -rf -- "$f"
              fi
            done
          }

          needed_bytes=0
          free_bytes=0

          enough_space() {
            local total avail reclaim
            total=$(unzip -l "$ZIP_PATH" 2>/dev/null | tail -1 | awk '{print $1}')
            case "''${total:-}" in ""|*[!0-9]*) return 0 ;; esac

            mkdir -p "$INSTALL_DIR"
            avail=$(df -B1 --output=avail "$INSTALL_DIR" 2>/dev/null | tail -1 | tr -cd '0-9')
            case "''${avail:-}" in ""|*[!0-9]*) return 0 ;; esac

            reclaim=0
            if install_dir_payload; then
              reclaim=$(du -s --block-size=1 --exclude='.${name}-*' "$INSTALL_DIR" 2>/dev/null | awk '{print $1}')
              case "''${reclaim:-}" in ""|*[!0-9]*) reclaim=0 ;; esac
            fi

            needed_bytes=$(( total + ${toString spareSpace} ))
            free_bytes=$(( avail + reclaim ))
            [ "$free_bytes" -ge "$needed_bytes" ]
          }

          choose_archive() {
            zinfo "$t_welcome"$'\n\n'"<small><tt>$INSTALL_DIR</tt></small>"

            ZIP_PATH=$(zenity --file-selection \
              --title="$t_select_zip" \
              --file-filter="$t_filter_zip | *.zip" \
              --file-filter="$t_filter_all | *" \
              2>/dev/null) || { zinfo "$t_cancelled"; exit 0; }

            [ -f "$ZIP_PATH" ] || { zerror "$t_file_not_found"$'\n\n'"$ZIP_PATH"; exit 1; }

            ${zipValidation}
          }

          run_install() {
            if ! safe_install_dir; then
              zerror "$t_unsafe_dir"$'\n\n'"$INSTALL_DIR"
              exit 1
            fi

            if ! enough_space; then
              zerror "$t_no_space"$'\n\n'"<tt>$(numfmt --to=iec "$needed_bytes") / $(numfmt --to=iec "$free_bytes")</tt>"
              exit 1
            fi

            if [ -f "$INCOMPLETE" ] || install_dir_payload; then
              if ! pulse "$t_cleaning" clean_install_dir; then
                zerror "$t_step_failed"$'\n\n'"$t_cleaning"$'\n\n'"<small>$t_see_log <tt>$LOG_FILE</tt></small>"
                exit 1
              fi
            fi

            mkdir -p "$INSTALL_DIR"
            touch "$INCOMPLETE"

            ${stepCalls}
            if [ ! -f "$BINARY" ]; then
              zerror "$t_binary_missing"$'\n\n'"<small>$t_see_log <tt>$LOG_FILE</tt></small>"
              exit 1
            fi

            chmod +x "$BINARY" 2>/dev/null || true
            rm -f "$INCOMPLETE"
            touch "$SENTINEL"
            zinfo "$t_done"
          }

          check_arg_path() {
            local target=$1 resolved
            [ -e "$target" ] || return 0
            resolved=$(realpath -- "$target" 2>/dev/null) || return 0
            case "$resolved" in
              "$HOME"/*) return 0 ;;
            esac
            zask "$t_path_outside_home"$'\n\n'"<tt>$resolved</tt>" || exit 0
          }

          launch_app() {
            if [ "$#" -gt 0 ]; then
              check_arg_path "$1"
            fi
            exec 9>&-
            # shellcheck disable=SC2016
            exec distrobox enter "$CONTAINER" -- bash -c \
              'cur=$(ulimit -n); case "$cur" in unlimited) ;; *) [ "$cur" -ge 65536 ] || ulimit -n 65536 2>/dev/null || true ;; esac; exec env "$@"' \
              ${name} ${envArgs} "$BINARY" "$@"
          }

          reinstall_app() {
            zask "$t_reinstall_confirm" || exit 0
            choose_archive
            container_ready || create_container
            rm -f "$SENTINEL"
            run_install
            launch_app
          }

          uninstall_app() {
            zask "$t_uninstall_confirm" || exit 0

            if ! safe_install_dir; then
              zerror "$t_unsafe_dir"$'\n\n'"$INSTALL_DIR"
              exit 1
            fi

            read_stamp

            pulse "$t_removing_container" distrobox rm --force "$CONTAINER" || true
            pulse "$t_removing_image" drop_image "$stamped_ref" "$stamped_id" || true
            pulse "$t_removing_files" rm -rf -- "$INSTALL_DIR" || true
            rm -f "$SENTINEL"
            rm -rf -- "$STATE_DIR"
            zinfo "$t_uninstalled"
          }

          require_podman

          fresh=0
          if [ ! -f "$SENTINEL" ]; then
            choose_archive
            container_ready || create_container
            run_install
            fresh=1
          elif ! container_ready; then
            rebuild_container
          fi

          if [ "$#" -gt 0 ] || [ "$fresh" = 1 ]; then
            launch_app "$@"
          fi

          choice=$(zenity --list \
            --title="$_TITLE" \
            --text="$t_menu_text" \
            --column="$t_menu_column" \
            "$t_menu_launch" \
            "$t_menu_reinstall" \
            "$t_menu_uninstall" \
            --width=420 --height=280 2>/dev/null) || exit 0

          case "$choice" in
            "$t_menu_launch")    launch_app ;;
            "$t_menu_reinstall") reinstall_app ;;
            "$t_menu_uninstall") uninstall_app ;;
          esac
        '';
      };

      enterScript = pkgs.writeShellApplication {
        name = "${name}-shell";
        runtimeInputs = [ pkgs.distrobox pkgs.podman ];
        text = ''
          export DBX_CONTAINER_MANAGER=podman
          exec distrobox enter ${lib.escapeShellArg containerName} -- \
            env ${envArgs} "''${@:-bash}"
        '';
      };

    in
    assert keysComplete;
    {
      inherit launcher enterScript;
      packages = [ launcher enterScript ];
    };
}
