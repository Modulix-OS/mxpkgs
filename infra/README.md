# Modulix binary cache (Attic)

`attic-cache.nix` is a standalone NixOS module for the server that hosts the
Modulix binary cache. It is **not** imported by `modulixos/`; import it in the
configuration of the machine that runs the cache, next to the agenix module —
this module declares an `age.secrets` entry but does not pull agenix in, so
that hosts which already import agenix do not end up with two copies of it.

Current deployment: `rpi-horgues` in `Config-raspberry`, served on
`https://cache.modulixos.org:16443/modulix`, local disk storage, certificate
issued through an OVH DNS-01 challenge (port 80 is not reachable on that line).

```nix
{
  imports = [ mxpkgs.nixosModules.attic-cache ];

  age.secrets.acme-ovh.file = ./secrets/rpi-horgues/acme-ovh.age;

  mx.infra.attic-cache = {
    enable = true;
    domain = "cache.modulixos.org";
    publicPort = 16443;
    secretFile = ./secrets/rpi-horgues/attic-env.age;
    nginx = {
      acmeEmail = "admin@modulixos.org";
      acme = {
        dnsProvider = "ovh";
        environmentFile = config.age.secrets.acme-ovh.path;
      };
    };
  };
}
```

`storage.type` defaults to `local` (`/var/lib/atticd/storage`, inside the
service's StateDirectory). Switch it to `s3` with `storage.s3.bucket` and
`storage.s3.endpoint` to offload the chunks to R2, B2 or Minio; the access keys
then go into the same agenix secret as the JWT key.

Metadata always lives in a local PostgreSQL database reached over its unix
socket with peer authentication, so there is no database password to manage.

## Secrets (agenix)

Everything in `services.atticd.settings` ends up world-readable in the Nix
store, so credentials only ever travel through agenix-encrypted
EnvironmentFiles, decrypted at activation time into ramfs under `/run/agenix`
and read by systemd before the services drop privileges.

`secretFile` holds:

```
ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=<openssl genrsa -traditional 4096 | base64 -w0>
```

plus `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` when storage is S3. That JWT
secret signs every token the server issues: rotating it invalidates all of
them, and leaking it lets anyone mint push tokens.

`nginx.acme.environmentFile` holds whatever lego expects for the provider, for
OVH:

```
OVH_ENDPOINT=ovh-eu
OVH_APPLICATION_KEY=…
OVH_APPLICATION_SECRET=…
OVH_CONSUMER_KEY=…
```

The recipient list lives in the host repository's `secrets.nix`, and must
include the server's own SSH host key — without it the machine cannot decrypt
its own secrets. Edit with `agenix -e <file>.age`, re-key with `agenix -r`
after changing the list.

By default agenix decrypts with the host SSH keys; set
`mx.infra.attic-cache.identityPaths` to override.

## Bootstrap, once the service is running

```sh
atticd-atticadm make-token --sub ci --validity '1y' \
  --create-cache 'modulix' --push 'modulix' --pull 'modulix' \
  --configure-cache 'modulix'

attic login modulix https://cache.modulixos.org:16443 <token>
attic cache create modulix
attic cache configure modulix --public
attic cache info modulix
```

`--public` is what makes the cache readable without a token, which is required
for it to work as a plain substituter. `attic cache info` prints the signing
public key.

## Wiring the consumers

- **CI**: in both `Modulix-OS/modulix-daemon` and
  `Modulix-OS/gnome-software-plugin`, set the variables `ATTIC_ENDPOINT`
  (`https://cache.modulixos.org:16443`), `ATTIC_CACHE` (`modulix`) and
  `ATTIC_PUBLIC_KEY`, plus the secret `ATTIC_TOKEN` (the token above).
  Setting them once at the organisation level covers both repositories.
  These stay GitHub-managed secrets: the runners hold no age identity, so
  agenix cannot feed them.
- **ModulixOS machines**: fill in `mx.cache.modulix.publicKey`
  (`modulixos/cache.nix`). The substituter stays off while that key is empty,
  since an unsigned cache would be rejected anyway.

The CI token carries push rights. Keep it out of `mx.cache.modulix`: machines
only ever need anonymous read access.

## Checking it works

```sh
nix build github:Modulix-OS/modulix-daemon#mx-daemon \
  --substituters https://cache.modulixos.org:16443/modulix \
  --trusted-public-keys '<public key>' -L
```

The output must show `copying path … from 'https://cache.modulixos.org:16443/modulix'`
and no `building` line.
