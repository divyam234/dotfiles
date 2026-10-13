{ den, ... }:
{
  den.aspects.imgresize = _: {
    nixos =
      { pkgs, ... }:
      {
        virtualisation.quadlet.containers.imgresize = {
          containerConfig = {
            image = "ghcr.io/divyam234/imgresize:latest";
            networkAliases = [ "imgresize" ];
            volumes = [ "/var/cache/images:/var/cache/images" ];
            environments = {
              THREAD_POOL = "8";
              RESIZE_WORKERS = "2";
              VIPS_CONCURRENCY = "1";
              CONN_LIMIT = "128";
              MAX_BODY_SIZE = "20MiB";
              BUFFER_MEMORY_SIZE = "64MiB";
              MAX_PIXELS = "25000000";
              CACHE_DIR = "/var/cache/images";
              CACHE_MAX_SIZE = "30GiB";
              CACHE_TTL_SECONDS = "31536000";
              CACHE_CLEANUP_SECONDS = "3600";
            };
          };
          unitConfig = {
            RequiresMountsFor = [ "/var/cache/images" ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -dm750 -o 1000 -g 100 /var/cache/images";
            MemoryMax = "1G";
            CPUQuota = "200%";
          };
        };
      };
  };
}
