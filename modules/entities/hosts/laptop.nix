_: {
  den.hosts.x86_64-linux.laptop = {
    secretsFile = ../../../hosts/laptop/secrets.yaml;
    rcloneWebdav = {
      remote = "tdrive:";
      port = 8888;
      configDatabaseHost = "netcup.tail69fe7a.ts.net";
      cors = true;
      extraArgs = [ "--teldrive-api-host=http://127.0.0.1:8887" ];
      cacheDir = "/mnt/drive/rclone";
      vfs = {
        cacheMode = "full";
        cacheMaxAge = "8670h";
        dirCacheTime = "24h";
        pollInterval = "1s";
        readAhead = "512M";
      };
    };
    teldrive = {
      databaseHost = "netcup.tail69fe7a.ts.net";
      download = {
        bots = 2;
      };
      exposeThroughCaddy = false;
      port = 8887;
      runWorkers = false;
      useMtproxy = false;
    };
    outputs = [
      {
        name = "eDP-1";
        off = true;
      }
      {
        name = "HDMI-A-2";
        mode = "1920x1080@74.973";
        scale = 1.25;
      }
      {
        name = "HDMI-A-1";
        mode = "1920x1080@74.973";
        scale = 1.25;
      }
    ];

    users.bhunter.classes = [ "user" ];
  };
}
