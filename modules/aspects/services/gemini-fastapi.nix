{ den, ... }:
{
  den.aspects.gemini-fastapi = { host, ... }: {
    nixosSecrets = [
      "gemini-fastapi/api_key"
      "gemini-fastapi/secure_1psid"
      "gemini-fastapi/secure_1psidts"
    ];

    caddyRoutes = {
      gemini-fastapi = {
        host = "gemini.${host.domain}";
        access = "tailnet";
        upstreams = [ "gemini-fastapi:8000" ];
      };
    };

    nixos =
      {
        containers,
        pkgs,
        user,
        secrets,
        ...
      }:
      {
        sops.templates."gemini-fastapi.env" = secrets.mkTemplate {
          name = "gemini-fastapi.env";
          content = ''
            CONFIG_SERVER__API_KEY=${secrets.gemini-fastapi.api_key}
            CONFIG_GEMINI__CLIENTS__0__ID=client-a
            CONFIG_GEMINI__CLIENTS__0__SECURE_1PSID=${secrets.gemini-fastapi.secure_1psid}
            CONFIG_GEMINI__CLIENTS__0__SECURE_1PSIDTS=${secrets.gemini-fastapi.secure_1psidts}
            CONFIG_GEMINI__CHAT_MODE=temporary
            CONFIG_GEMINI__MAX_CHARS_PER_REQUEST=1000000
            CONFIG_GEMINI__OVERSIZED_CONTEXT_STRATEGY=compaction
          '';
        };

        virtualisation.quadlet.containers.gemini-fastapi = {
          containerConfig = {
            image = "ghcr.io/divyam234/gemini-fastapi:latest";
            networkAliases = [ "gemini-fastapi" ];
            environmentFiles = [ "${containers.secretDir}/gemini-fastapi.env" ];
            environments = {
              CONFIG_SERVER__HOST = "0.0.0.0";
              CONFIG_SERVER__PORT = "8000";
              GEMINI_COOKIE_PATH = "/app/cache"; # must match the cache volume mount above
            };
            volumes = [
              "${containers.dataRoot}/gemini-fastapi/data:/app/data"
              "${containers.dataRoot}/gemini-fastapi/cache:/app/cache"
            ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/gemini-fastapi/data ${containers.dataRoot}/gemini-fastapi/cache";
            MemoryMax = "1G";
            CPUQuota = "100%";
          };
        };
      };
  };
}
