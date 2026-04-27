 { config } :

let
  allUsers = builtins.attrNames config.users.users;
in
builtins.filter (user: config.users.users.${user}.isNormalUser) allUsers
