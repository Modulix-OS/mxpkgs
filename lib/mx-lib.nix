# Priorités ModulixOS pour le module system.
# Rappel : plus la valeur est basse, plus la priorité est forte.
{ lib }:
{
  # Priorité des défauts ModulixOS : bat mkDefault (1000) et mkOptionDefault (1500),
  # reste écrasable par une définition normale de l'utilisateur (100) et par mkForce (50).
  mxDefaultPriority = 900;

  # Wrapper de mkOverride. À utiliser pour toute option amont nixpkgs dont ModulixOS
  # fixe une valeur de politique / de réglage.
  mkMxDefault = lib.mkOverride 900;
}
