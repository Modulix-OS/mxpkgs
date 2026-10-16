{ pkgs ? import <nixpkgs> {} }:

let
  script = pkgs.writeShellApplication {
    name = "mx-diff-update";
    runtimeInputs = [ pkgs.nix pkgs.coreutils pkgs.findutils ];
    text = ''
      profiles=/nix/var/nix/profiles

      generation_link() {
        local n=$1
        if [[ ! $n =~ ^[0-9]+$ ]]; then
          echo "mx-diff-update: '$n' is not a generation number" >&2
          exit 1
        fi
        local link="$profiles/system-$n-link"
        if [[ ! -e $link ]]; then
          echo "mx-diff-update: generation $n not found" >&2
          exit 1
        fi
        echo "$link"
      }

      sorted_links() {
        find "$profiles" -maxdepth 1 -name 'system-*-link' | sort -V
      }

      case $# in
        0)
          old=$(sorted_links | tail -n 2 | head -n 1)
          new=$(sorted_links | tail -n 1)
          if [[ -z $old || $old == "$new" ]]; then
            echo "mx-diff-update: fewer than two generations available" >&2
            exit 1
          fi
          ;;
        1)
          old=$(generation_link "$1")
          new=$(sorted_links | tail -n 1)
          ;;
        2)
          link_a=$(generation_link "$1")
          link_b=$(generation_link "$2")
          if (( 10#$1 > 10#$2 )); then
            old=$link_b
            new=$link_a
          else
            old=$link_a
            new=$link_b
          fi
          ;;
        *)
          echo "usage: mx-diff-update [N [M]]" >&2
          exit 1
          ;;
      esac

      nix store diff-closures "$old" "$new"
    '';
  };

  bashCompletion = pkgs.writeTextFile {
    name = "mx-diff-update-bash-completion";
    destination = "/share/bash-completion/completions/mx-diff-update";
    text = ''
      _mx_diff_update() {
        (( COMP_CWORD > 2 )) && return
        local gens
        gens=$(ls -1 /nix/var/nix/profiles 2>/dev/null \
          | sed -n 's/^system-\([0-9]\+\)-link$/\1/p' | sort -n)
        mapfile -t COMPREPLY < <(compgen -W "$gens" -- "$2")
      }
      complete -F _mx_diff_update mx-diff-update
    '';
  };

  zshCompletion = pkgs.writeTextFile {
    name = "mx-diff-update-zsh-completion";
    destination = "/share/zsh/site-functions/_mx-diff-update";
    text = ''
      #compdef mx-diff-update

      _mx_diff_update() {
        (( CURRENT <= 3 )) || return 1
        local -a gens
        gens=( /nix/var/nix/profiles/system-*-link(Non:t) )
        gens=( ''${gens#system-} )
        gens=( ''${gens%-link} )
        compadd -V generations -a gens
      }

      _mx_diff_update "$@"
    '';
  };

  fishCompletion = pkgs.writeTextFile {
    name = "mx-diff-update-fish-completion";
    destination = "/share/fish/vendor_completions.d/mx-diff-update.fish";
    text = ''
      function __mx_diff_update_generations
        command ls -1 /nix/var/nix/profiles 2>/dev/null \
          | string replace -rf '^system-(\d+)-link$' '$1' \
          | sort -n
      end

      complete -c mx-diff-update -f \
        -n 'test (count (commandline -opc)) -lt 3' \
        -a '(__mx_diff_update_generations)'
    '';
  };
in
pkgs.symlinkJoin {
  name = "mx-diff-update";
  paths = [ script bashCompletion zshCompletion fishCompletion ];
  meta.mainProgram = "mx-diff-update";
}
