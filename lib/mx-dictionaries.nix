{ lib, pkgs }:

let
  table = {
    "fr" = { dict = pkgs.hunspellDicts.fr-moderne; file = "fr-moderne"; locale = "fr_FR"; hyphen = pkgs.hyphenDicts.fr_FR; };
    "en-US" = { dict = pkgs.hunspellDicts.en_US; file = "en_US"; locale = "en_US"; hyphen = pkgs.hyphenDicts.en_US; };
    "en-GB" = { dict = pkgs.hunspellDicts.en_GB-ise; file = "en_GB"; locale = "en_GB"; hyphen = pkgs.hyphenDicts.en_GB; };
    "de" = { dict = pkgs.hunspellDicts.de_DE; file = "de_DE"; locale = "de_DE"; hyphen = pkgs.hyphenDicts.de_DE; };
    "es-ES" = { dict = pkgs.hunspellDicts.es_ES; file = "es_ES"; locale = "es_ES"; hyphen = pkgs.hyphenDicts.es_ES; };
    "it" = { dict = pkgs.hunspellDicts.it_IT; file = "it_IT"; locale = "it_IT"; hyphen = pkgs.hyphenDicts.it_IT; };
    "pt-BR" = { dict = pkgs.hunspellDicts.pt_BR; file = "pt_BR"; locale = "pt_BR"; hyphen = pkgs.hyphenDicts.pt_BR; };
    "nl" = { dict = pkgs.hunspellDicts.nl_NL; file = "nl_NL"; locale = "nl_NL"; hyphen = pkgs.hyphenDicts.nl_NL; };
  };

  supported = langs: lib.filter (lang: table ? ${lang}) langs;

  unsupported = langs: lib.filter (lang: !(table ? ${lang})) langs;

  hunspellEnv = { name, langs }: pkgs.runCommand name { } (''
    mkdir -p $out/share/hunspell
  '' + lib.concatMapStrings (lang: ''
    ln -s ${table.${lang}.dict}/share/hunspell/${table.${lang}.file}.aff $out/share/hunspell/${lang}.aff
    ln -s ${table.${lang}.dict}/share/hunspell/${table.${lang}.file}.dic $out/share/hunspell/${lang}.dic
  '') (supported langs));

  packages = langs: lib.concatMap
    (lang: [ table.${lang}.dict ] ++ lib.optional (table.${lang}.hyphen != null) table.${lang}.hyphen)
    (supported langs);
in
{
  inherit table supported unsupported hunspellEnv packages;
}
