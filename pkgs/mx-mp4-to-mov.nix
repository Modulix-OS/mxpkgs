{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;

  translations = {
    en = {
      t_title = "MP4 to MOV";
      t_intro = "<big><b>Convert MP4 to MOV</b></big>\n\nRe-encodes MP4 footage into a MOV file that DaVinci Resolve reads natively, audio included.\n\nPress Browse to choose the files.";
      t_browse = "Browse";
      t_no_display = "needs a graphical session (neither DISPLAY nor WAYLAND_DISPLAY is set).";
      t_select = "Select the MP4 files to convert";
      t_filter_video = "Video files";
      t_filter_all = "All files";
      t_queue_text = "Files to convert";
      t_queue_format = "Format:";
      t_col_file = "File";
      t_convert = "Convert";
      t_quit = "Quit";
      t_add = "Add files";
      t_remove = "Remove";
      t_format_button = "Format";
      t_remove_text = "Select the files to remove from the list";
      t_empty = "The list is empty: add at least one file.";
      t_preset_text = "Output format";
      t_col_preset = "Format";
      t_p_dnxhr_hq = "DNxHR HQ - recommended, reads natively in Resolve";
      t_p_dnxhr_sq = "DNxHR SQ - smaller files, slightly lower quality";
      t_p_prores = "ProRes 422";
      t_p_copy = "Change the container only - keeps H.264, unreadable in the free edition";
      t_short_copy = "Container only";
      t_outdir = "Choose the output folder";
      t_not_writable = "This folder is not writable:";
      t_progress_title = "Converting";
      t_preparing = "Preparing...";
      t_converting = "Converting";
      t_of = "of";
      t_done = "Conversion finished.";
      t_done_files = "file(s) written to";
      t_cancelled = "Conversion cancelled.";
      t_log_title = "ffmpeg log";
    };

    fr = {
      t_title = "MP4 vers MOV";
      t_intro = "<big><b>Convertir des MP4 en MOV</b></big>\n\nRéencode vos MP4 en un fichier MOV lu nativement par DaVinci Resolve, audio compris.\n\nCliquez sur Parcourir pour choisir les fichiers.";
      t_browse = "Parcourir";
      t_no_display = "nécessite une session graphique (ni DISPLAY ni WAYLAND_DISPLAY n'est défini).";
      t_select = "Choisissez les fichiers MP4 à convertir";
      t_filter_video = "Fichiers vidéo";
      t_filter_all = "Tous les fichiers";
      t_queue_text = "Fichiers à convertir";
      t_queue_format = "Format :";
      t_col_file = "Fichier";
      t_convert = "Convertir";
      t_quit = "Quitter";
      t_add = "Ajouter des fichiers";
      t_remove = "Retirer";
      t_format_button = "Format";
      t_remove_text = "Choisissez les fichiers à retirer de la liste";
      t_empty = "La liste est vide : ajoutez au moins un fichier.";
      t_preset_text = "Format de sortie";
      t_col_preset = "Format";
      t_p_dnxhr_hq = "DNxHR HQ - recommandé, lu nativement par Resolve";
      t_p_dnxhr_sq = "DNxHR SQ - fichiers plus légers, qualité un peu moindre";
      t_p_prores = "ProRes 422";
      t_p_copy = "Changer seulement le conteneur - garde le H.264, illisible dans l'édition gratuite";
      t_short_copy = "Conteneur seul";
      t_outdir = "Choisissez le dossier de sortie";
      t_not_writable = "Ce dossier n'est pas accessible en écriture :";
      t_progress_title = "Conversion";
      t_preparing = "Préparation...";
      t_converting = "Conversion";
      t_of = "sur";
      t_done = "Conversion terminée.";
      t_done_files = "fichier(s) écrit(s) dans";
      t_cancelled = "Conversion annulée.";
      t_log_title = "Journal ffmpeg";
    };

    es = {
      t_title = "MP4 a MOV";
      t_intro = "<big><b>Convertir MP4 a MOV</b></big>\n\nVuelve a codificar sus archivos MP4 en un MOV que DaVinci Resolve lee de forma nativa, audio incluido.\n\nPulse Explorar para elegir los archivos.";
      t_browse = "Explorar";
      t_no_display = "necesita una sesión gráfica (ni DISPLAY ni WAYLAND_DISPLAY están definidos).";
      t_select = "Elija los archivos MP4 que desea convertir";
      t_filter_video = "Archivos de vídeo";
      t_filter_all = "Todos los archivos";
      t_queue_text = "Archivos por convertir";
      t_queue_format = "Formato:";
      t_col_file = "Archivo";
      t_convert = "Convertir";
      t_quit = "Salir";
      t_add = "Añadir archivos";
      t_remove = "Quitar";
      t_format_button = "Formato";
      t_remove_text = "Elija los archivos que desea quitar de la lista";
      t_empty = "La lista está vacía: añada al menos un archivo.";
      t_preset_text = "Formato de salida";
      t_col_preset = "Formato";
      t_p_dnxhr_hq = "DNxHR HQ - recomendado, Resolve lo lee de forma nativa";
      t_p_dnxhr_sq = "DNxHR SQ - archivos más ligeros, calidad algo menor";
      t_p_prores = "ProRes 422";
      t_p_copy = "Cambiar solo el contenedor - mantiene H.264, ilegible en la edición gratuita";
      t_short_copy = "Solo contenedor";
      t_outdir = "Elija la carpeta de salida";
      t_not_writable = "No se puede escribir en esta carpeta:";
      t_progress_title = "Conversión";
      t_preparing = "Preparando...";
      t_converting = "Convirtiendo";
      t_of = "de";
      t_done = "Conversión finalizada.";
      t_done_files = "archivo(s) escrito(s) en";
      t_cancelled = "Conversión cancelada.";
      t_log_title = "Registro de ffmpeg";
    };

    de = {
      t_title = "MP4 zu MOV";
      t_intro = "<big><b>MP4 zu MOV umwandeln</b></big>\n\nKodiert MP4-Material in eine MOV-Datei, die DaVinci Resolve direkt liest, samt Ton.\n\nKlicken Sie auf Durchsuchen, um die Dateien zu wählen.";
      t_browse = "Durchsuchen";
      t_no_display = "benötigt eine grafische Sitzung (weder DISPLAY noch WAYLAND_DISPLAY ist gesetzt).";
      t_select = "Wählen Sie die MP4-Dateien zum Umwandeln";
      t_filter_video = "Videodateien";
      t_filter_all = "Alle Dateien";
      t_queue_text = "Dateien zum Umwandeln";
      t_queue_format = "Format:";
      t_col_file = "Datei";
      t_convert = "Umwandeln";
      t_quit = "Beenden";
      t_add = "Dateien hinzufügen";
      t_remove = "Entfernen";
      t_format_button = "Format";
      t_remove_text = "Wählen Sie die Dateien, die aus der Liste entfernt werden sollen";
      t_empty = "Die Liste ist leer: fügen Sie mindestens eine Datei hinzu.";
      t_preset_text = "Ausgabeformat";
      t_col_preset = "Format";
      t_p_dnxhr_hq = "DNxHR HQ - empfohlen, wird von Resolve direkt gelesen";
      t_p_dnxhr_sq = "DNxHR SQ - kleinere Dateien, etwas geringere Qualität";
      t_p_prores = "ProRes 422";
      t_p_copy = "Nur den Container ändern - behält H.264, in der kostenlosen Ausgabe unlesbar";
      t_short_copy = "Nur Container";
      t_outdir = "Wählen Sie den Ausgabeordner";
      t_not_writable = "In diesen Ordner kann nicht geschrieben werden:";
      t_progress_title = "Umwandlung";
      t_preparing = "Vorbereitung...";
      t_converting = "Umwandeln";
      t_of = "von";
      t_done = "Umwandlung abgeschlossen.";
      t_done_files = "Datei(en) geschrieben nach";
      t_cancelled = "Umwandlung abgebrochen.";
      t_log_title = "ffmpeg-Protokoll";
    };
  };

  sameKeys =
    let
      ref = lib.attrNames translations.en;
    in
    lib.all (t: lib.attrNames t == ref) (lib.attrValues translations);

  mkCase = pattern: strings: ''
    ${pattern})
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "  ${name}=${lib.escapeShellArg value}") strings
    )}
      ;;
  '';

  langCase = ''
    case "$lang" in
    ${mkCase "fr" translations.fr}
    ${mkCase "es" translations.es}
    ${mkCase "de" translations.de}
    ${mkCase "*" translations.en}
    esac
  '';

  helpText = ''
    mx-mp4-to-mov - convert MP4 footage to MOV for DaVinci Resolve

    Usage: mx-mp4-to-mov

    Opens an intro window with a Browse button, then lists the files you picked.
    The output folder is asked for when you press Convert. The output format is
    DNxHR HQ unless you change it with the Format button.

    The free edition of DaVinci Resolve ships no H.264, H.265 or AAC licence on
    Linux, so the default preset re-encodes rather than only swapping the container.

    Environment:
      MX_MP4_TO_MOV_LANG    force the interface language (en, fr, es, de)
      MX_MP4_TO_MOV_TRACE   append one line per dialogue opened to this file
  '';

  script = pkgs.writeShellApplication {
    name = "mx-mp4-to-mov";
    runtimeInputs = [
      pkgs.zenity
      pkgs.ffmpeg-headless
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      RED='\033[0;31m'
      NC='\033[0m'

      case "''${1:-}" in
        -h|--help)
          printf '%s' ${lib.escapeShellArg helpText}
          exit 0
          ;;
        "")
          ;;
        *)
          printf '%b\n' "''${RED}mx-mp4-to-mov''${NC}: unexpected argument '$1'" >&2
          exit 2
          ;;
      esac

      lang=''${MX_MP4_TO_MOV_LANG:-''${LC_ALL:-''${LC_MESSAGES:-''${LANG:-en}}}}
      lang=''${lang%%.*}
      lang=''${lang%%@*}
      lang=''${lang%%_*}
      lang=''${lang,,}

      ${langCase}

      if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        printf '%b\n' "''${RED}mx-mp4-to-mov''${NC}: $t_no_display" >&2
        exit 1
      fi

      trace() {
        if [ -n "''${MX_MP4_TO_MOV_TRACE:-}" ]; then
          printf '%s %s\n' "$(date +%T.%3N)" "$1" >> "$MX_MP4_TO_MOV_TRACE"
        fi
      }

      spins=0
      spin_start=$SECONDS

      guard_spin() {
        if [ $(( SECONDS - spin_start )) -ge 4 ]; then
          spins=0
          spin_start=$SECONDS
          return 0
        fi
        spins=$((spins + 1))
        if [ "$spins" -gt 12 ]; then
          trace "spin-guard-abort"
          printf '%b\n' "''${RED}mx-mp4-to-mov''${NC}: dialogue loop detected, aborting" >&2
          exit 1
        fi
      }

      files=()
      preset=dnxhr_hq

      preset_label() {
        case "$1" in
          dnxhr_hq) printf '%s\n' "$t_p_dnxhr_hq" ;;
          dnxhr_sq) printf '%s\n' "$t_p_dnxhr_sq" ;;
          prores) printf '%s\n' "$t_p_prores" ;;
          *) printf '%s\n' "$t_p_copy" ;;
        esac
      }

      preset_short() {
        case "$preset" in
          dnxhr_hq) printf 'DNxHR HQ\n' ;;
          dnxhr_sq) printf 'DNxHR SQ\n' ;;
          prores) printf 'ProRes 422\n' ;;
          *) printf '%s\n' "$t_short_copy" ;;
        esac
      }

      pick_files() {
        trace "file-selection"
        zenity --file-selection --multiple --separator=$'\n' \
          --title="$t_select" \
          --file-filter="$t_filter_video | *.mp4 *.MP4 *.m4v *.M4V" \
          --file-filter="$t_filter_all | *"
      }

      dedupe() {
        local -a unique=()
        local candidate existing seen
        for candidate in "''${files[@]}"; do
          seen=0
          for existing in "''${unique[@]}"; do
            if [ "$candidate" = "$existing" ]; then
              seen=1
              break
            fi
          done
          if [ "$seen" -eq 0 ]; then
            unique+=("$candidate")
          fi
        done
        files=("''${unique[@]}")
      }

      add_files() {
        local -a picked=()
        mapfile -t picked < <(pick_files)
        if [ "''${#picked[@]}" -gt 0 ]; then
          files+=("''${picked[@]}")
          dedupe
        fi
      }

      remove_files() {
        local -a rows=() selected=() keep=()
        local status=0 answer candidate entry hit
        for entry in "''${files[@]}"; do
          rows+=(FALSE "$entry")
        done
        trace "remove-checklist"
        answer=$(zenity --list --checklist \
          --title="$t_title" --text="$t_remove_text" \
          --column="" --column="$t_col_file" \
          --separator=$'\n' --width=700 --height=420 \
          -- "''${rows[@]}") || status=$?
        if [ "$status" -ne 0 ]; then
          return 0
        fi
        mapfile -t selected <<< "$answer"
        for candidate in "''${files[@]}"; do
          hit=0
          for entry in "''${selected[@]}"; do
            if [ "$candidate" = "$entry" ]; then
              hit=1
              break
            fi
          done
          if [ "$hit" -eq 0 ]; then
            keep+=("$candidate")
          fi
        done
        files=("''${keep[@]}")
      }

      choose_preset() {
        local -a rows=()
        local status=0 answer key
        for key in dnxhr_hq dnxhr_sq prores copy; do
          if [ "$key" = "$preset" ]; then
            rows+=(TRUE)
          else
            rows+=(FALSE)
          fi
          rows+=("$(preset_label "$key")" "$key")
        done
        trace "preset-radiolist"
        answer=$(zenity --list --radiolist \
          --title="$t_title" --text="$t_preset_text" \
          --column="" --column="$t_col_preset" --column="key" \
          --hide-column=3 --print-column=3 \
          --width=640 --height=320 \
          -- "''${rows[@]}") || status=$?
        if [ "$status" -eq 0 ] && [ -n "$answer" ]; then
          preset=$answer
        fi
      }

      unique_path() {
        local dir=$1 base=$2 candidate index
        candidate="$dir/$base.mov"
        index=1
        while [ -e "$candidate" ]; do
          candidate="$dir/$base-$index.mov"
          index=$((index + 1))
        done
        printf '%s\n' "$candidate"
      }

      duration_us() {
        local raw
        raw=$(ffprobe -v error -show_entries format=duration \
          -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null) || raw=""
        if [ -z "$raw" ] || [ "$raw" = "N/A" ]; then
          printf '0\n'
          return 0
        fi
        awk -v value="$raw" 'BEGIN { printf "%d\n", value * 1000000 }'
      }

      read_progress() {
        awk -F= '/^out_time_us=/ { value = $2 } END { printf "%d\n", value + 0 }' \
          "$1" 2>/dev/null || printf '0\n'
      }

      while true; do
        guard_spin
        status=0
        trace "intro"
        zenity --question --title="$t_title" --text="$t_intro" \
          --ok-label="$t_browse" --cancel-label="$t_quit" --width=520 || status=$?
        if [ "$status" -ne 0 ]; then
          exit 0
        fi
        add_files
        if [ "''${#files[@]}" -gt 0 ]; then
          break
        fi
      done

      while true; do
        guard_spin
        status=0
        trace "queue"
        action=$(zenity --list \
          --title="$t_title" \
          --text="$t_queue_text (''${#files[@]}) - $t_queue_format $(preset_short)" \
          --column="$t_col_file" \
          --width=700 --height=420 \
          --ok-label="$t_convert" --cancel-label="$t_quit" \
          --extra-button="$t_add" --extra-button="$t_remove" \
          --extra-button="$t_format_button" \
          -- "''${files[@]}") || status=$?
        if [ "$status" -eq 0 ]; then
          if [ "''${#files[@]}" -gt 0 ]; then
            break
          fi
          trace "empty-warning"
          zenity --warning --title="$t_title" --text="$t_empty" || true
          add_files
          continue
        fi
        if [ "$status" -ne 1 ]; then
          exit 0
        fi
        case "$action" in
          "$t_add")
            add_files
            ;;
          "$t_remove")
            remove_files
            ;;
          "$t_format_button")
            choose_preset
            ;;
          *)
            exit 0
            ;;
        esac
      done

      case "$preset" in
        dnxhr_hq)
          encode=(-c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p -c:a pcm_s16le)
          ;;
        dnxhr_sq)
          encode=(-c:v dnxhd -profile:v dnxhr_sq -pix_fmt yuv422p -c:a pcm_s16le)
          ;;
        prores)
          encode=(-c:v prores_ks -profile:v 2 -pix_fmt yuv422p10le -c:a pcm_s16le)
          ;;
        copy)
          encode=(-c copy -movflags +faststart)
          ;;
        *)
          exit 1
          ;;
      esac

      status=0
      trace "outdir"
      outdir=$(zenity --file-selection --directory --title="$t_outdir") || status=$?
      if [ "$status" -ne 0 ] || [ -z "$outdir" ]; then
        exit 0
      fi
      if [ ! -w "$outdir" ]; then
        trace "not-writable-error"
        zenity --error --title="$t_title" --text="$t_not_writable"$'\n'"$outdir" || true
        exit 1
      fi

      fifo=$(mktemp -u -t mx-mp4-to-mov.XXXXXXXX)
      log=$(mktemp -t mx-mp4-to-mov.XXXXXXXX.log)
      progress=$(mktemp -t mx-mp4-to-mov.XXXXXXXX.progress)
      mkfifo -m 600 "$fifo"

      cleanup() {
        rm -f -- "$fifo" "$log" "$progress"
      }
      trap cleanup EXIT
      trap "" PIPE

      trace "progress"
      zenity --progress --title="$t_progress_title" --text="$t_preparing" \
        --percentage=0 --auto-close --width=480 < "$fifo" &
      zenity_pid=$!
      exec 3> "$fifo"

      total=''${#files[@]}
      finished=0
      written=0
      cancelled=0
      failures=()

      for source in "''${files[@]}"; do
        base=''${source##*/}
        base=''${base%.*}
        target=$(unique_path "$outdir" "$base")
        total_us=$(duration_us "$source")
        : > "$progress"
        printf '# %s %d %s %d: %s\n' \
          "$t_converting" "$((finished + 1))" "$t_of" "$total" "$base" >&3 2>/dev/null || true
        ffmpeg -nostdin -hide_banner -y -progress "$progress" -nostats \
          -i "$source" -map 0:v -map '0:a?' "''${encode[@]}" "$target" >>"$log" 2>&1 &
        ffmpeg_pid=$!
        while kill -0 "$ffmpeg_pid" 2>/dev/null; do
          if ! kill -0 "$zenity_pid" 2>/dev/null; then
            kill -TERM "$ffmpeg_pid" 2>/dev/null || true
            waited=0
            while kill -0 "$ffmpeg_pid" 2>/dev/null && [ "$waited" -lt 6 ]; do
              sleep 0.5
              waited=$((waited + 1))
            done
            if kill -0 "$ffmpeg_pid" 2>/dev/null; then
              kill -KILL "$ffmpeg_pid" 2>/dev/null || true
            fi
            wait "$ffmpeg_pid" 2>/dev/null || true
            rm -f -- "$target"
            cancelled=1
            break 2
          fi
          share=0
          if [ "$total_us" -gt 0 ]; then
            current=$(read_progress "$progress")
            share=$(( current * 100 / total_us ))
          fi
          percent=$(( (finished * 100 + share) / total ))
          if [ "$percent" -gt 99 ]; then
            percent=99
          fi
          printf '%d\n' "$percent" >&3 2>/dev/null || true
          sleep 0.5
        done
        status=0
        wait "$ffmpeg_pid" || status=$?
        if [ "$status" -eq 0 ]; then
          written=$((written + 1))
        else
          failures+=("$source")
          rm -f -- "$target"
        fi
        finished=$((finished + 1))
        if [ "$finished" -lt "$total" ]; then
          printf '%d\n' "$(( finished * 100 / total ))" >&3 2>/dev/null || true
        fi
      done

      printf '100\n' >&3 2>/dev/null || true
      exec 3>&- 2>/dev/null || true
      wait "$zenity_pid" 2>/dev/null || true

      if [ "$cancelled" -eq 1 ]; then
        trace "cancelled-warning"
        zenity --warning --title="$t_title" --text="$t_cancelled" || true
        exit 1
      fi

      if [ "''${#failures[@]}" -gt 0 ]; then
        trace "failure-log"
        zenity --text-info --title="$t_log_title" --filename="$log" \
          --width=820 --height=520 || true
        exit 1
      fi

      trace "summary"
      zenity --info --title="$t_title" \
        --text="$t_done"$'\n'"$written $t_done_files"$'\n'"$outdir" || true
    '';
  };

  desktopItem = pkgs.writeTextFile {
    name = "mx-mp4-to-mov-desktop-item";
    destination = "/share/applications/mx-mp4-to-mov.desktop";
    text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=MP4 to MOV
      Name[fr]=MP4 vers MOV
      Name[es]=MP4 a MOV
      Name[de]=MP4 zu MOV
      GenericName=Video converter
      GenericName[fr]=Convertisseur vidéo
      GenericName[es]=Conversor de vídeo
      GenericName[de]=Video-Konverter
      Comment=Convert MP4 footage to MOV that DaVinci Resolve reads natively
      Comment[fr]=Convertir des MP4 en MOV lisibles nativement par DaVinci Resolve
      Comment[es]=Convertir archivos MP4 a MOV que DaVinci Resolve lee de forma nativa
      Comment[de]=MP4-Material in MOV umwandeln, das DaVinci Resolve direkt liest
      Exec=mx-mp4-to-mov
      Icon=video-x-generic
      Terminal=false
      Categories=AudioVideo;Video;
      Keywords=mp4;mov;dnxhr;prores;ffmpeg;resolve;
    '';
  };
in
assert sameKeys;
pkgs.symlinkJoin {
  name = "mx-mp4-to-mov";
  paths = [ script desktopItem ];
  meta.mainProgram = "mx-mp4-to-mov";
}
