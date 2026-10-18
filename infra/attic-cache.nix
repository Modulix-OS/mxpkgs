{ config, lib, ... }:
let
  cfg = config.mx.infra.attic-cache;
  secretName = "attic-cache-env";
  defaultPort = cfg.publicPort == 443;
  publicUrl = "https://${cfg.domain}" + lib.optionalString (!defaultPort) ":${toString cfg.publicPort}";
  useDns = cfg.nginx.acme.dnsProvider != null;
in
{
  options.mx.infra.attic-cache = {
    enable = lib.mkEnableOption "the Modulix Attic binary cache server";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "cache.modulixos.org";
      description = ''
        Public hostname the cache is served on. Used for the ACME certificate,
        the nginx virtual host and the `api-endpoint` advertised to clients.
      '';
    };

    publicPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      example = 8443;
      description = ''
        Port nginx serves the cache on, and the port clients are told to use.
        Anything other than 443 is appended to the advertised URL, so the
        substituter is `https://domain:port/<cache>`.
      '';
    };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8080";
      description = "Address atticd binds to, behind the reverse proxy.";
    };

    secretFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression "./secrets/rpi-horgues/attic-env.age";
      description = ''
        agenix-encrypted EnvironmentFile for atticd. It is decrypted at
        activation time to `/run/agenix/attic-cache-env`, owned by root, and
        read by systemd before the service drops privileges. Its plaintext
        holds `ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64`, from
        `openssl genrsa -traditional 4096 | base64 -w0`, plus
        `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` when `storage.type`
        is `s3`.

        The host configuration must import the agenix NixOS module; this
        module only declares the secret.
      '';
    };

    identityPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = [ "/etc/ssh/ssh_host_ed25519_key" ];
      description = ''
        Private keys agenix tries when decrypting secrets. Left empty, the
        agenix default applies, which is the SSH host keys.
      '';
    };

    retention = lib.mkOption {
      type = lib.types.str;
      default = "3 months";
      description = ''
        Retention period for store paths no cache still references. Garbage
        collection runs every 12 hours.
      '';
    };

    storage = {
      type = lib.mkOption {
        type = lib.types.enum [ "local" "s3" ];
        default = "local";
        description = ''
          Where NAR chunks are kept: on the server's own disk, or in an
          S3-compatible bucket.
        '';
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/atticd/storage";
        description = ''
          Directory holding the chunks when `type` is `local`. Staying under
          `/var/lib/atticd` keeps it inside the service's StateDirectory.
        '';
      };

      s3 = {
        bucket = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "modulix-nix-cache";
          description = "S3 bucket holding the NAR chunks when `type` is `s3`.";
        };

        region = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = ''
            S3 region. Cloudflare R2 expects `auto`; Backblaze B2 and Minio
            expect their own region name.
          '';
        };

        endpoint = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "https://<account>.r2.cloudflarestorage.com";
          description = "S3 API endpoint of the provider.";
        };
      };
    };

    nginx = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to configure nginx as a TLS terminating reverse proxy in
          front of atticd. Disable to plug atticd into an existing proxy.
        '';
      };

      acmeEmail = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Contact address for the Let's Encrypt account.";
      };

      acme = {
        dnsProvider = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "ovh";
          description = ''
            lego DNS provider code for a DNS-01 challenge. Required when port
            80 cannot reach this host, since HTTP-01 is then impossible.
            `null` keeps the HTTP-01 challenge, which needs port 80 open.
          '';
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression "config.age.secrets.acme-ovh.path";
          description = ''
            Decrypted EnvironmentFile holding the DNS provider credentials
            lego expects, e.g. `OVH_APPLICATION_KEY` and friends. Point it at
            an agenix secret path.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.nginx.enable || cfg.nginx.acmeEmail != "";
        message = "mx.infra.attic-cache.nginx.acmeEmail must be set when nginx is enabled.";
      }
      {
        assertion = !useDns || cfg.nginx.acme.environmentFile != null;
        message = "mx.infra.attic-cache.nginx.acme.environmentFile must be set when a dnsProvider is used.";
      }
      {
        assertion = cfg.storage.type != "s3" || (cfg.storage.s3.bucket != "" && cfg.storage.s3.endpoint != "");
        message = "mx.infra.attic-cache.storage.s3.bucket and .endpoint must be set when storage.type is \"s3\".";
      }
    ];

    age.identityPaths = lib.mkIf (cfg.identityPaths != [ ]) cfg.identityPaths;

    age.secrets.${secretName} = {
      file = cfg.secretFile;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    services.atticd = {
      enable = true;
      environmentFile = config.age.secrets.${secretName}.path;
      settings = {
        listen = cfg.listen;
        api-endpoint = "${publicUrl}/";
        allowed-hosts = lib.unique [ cfg.domain "${cfg.domain}:${toString cfg.publicPort}" ];

        database.url = "postgresql:///atticd?host=/run/postgresql";

        storage =
          if cfg.storage.type == "s3" then
            {
              type = "s3";
              inherit (cfg.storage.s3) bucket region endpoint;
            }
          else
            {
              type = "local";
              path = cfg.storage.path;
            };

        compression.type = "zstd";

        garbage-collection = {
          interval = "12 hours";
          default-retention-period = cfg.retention;
        };
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "atticd" ];
      ensureUsers = [
        {
          name = config.services.atticd.user;
          ensureDBOwnership = true;
        }
      ];
    };

    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      virtualHosts.${cfg.domain} = {
        onlySSL = true;
        enableACME = !useDns;
        useACMEHost = lib.mkIf useDns cfg.domain;
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.publicPort;
            ssl = true;
          }
          {
            addr = "[::]";
            port = cfg.publicPort;
            ssl = true;
          }
        ];
        locations."/" = {
          proxyPass = "http://${cfg.listen}";
          extraConfig = ''
            client_max_body_size 8G;
            proxy_request_buffering off;
            proxy_read_timeout 600s;
          '';
        };
      };
    };

    security.acme = lib.mkIf cfg.nginx.enable {
      acceptTerms = true;
      defaults.email = cfg.nginx.acmeEmail;
      certs.${cfg.domain} = lib.mkIf useDns {
        domain = cfg.domain;
        dnsProvider = cfg.nginx.acme.dnsProvider;
        environmentFile = cfg.nginx.acme.environmentFile;
        group = config.services.nginx.group;
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.nginx.enable ([ cfg.publicPort ] ++ lib.optional (!useDns) 80);
  };
}
