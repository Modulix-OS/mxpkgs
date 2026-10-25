final: prev: {
  gnome-shell = prev.gnome-shell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/0001-appDisplay-refresh-the-app-info-list-before-folders.patch
    ];
  });
}
