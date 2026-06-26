{
  adguard = {
    description = "AdGuard CLI service exposed through Gluetun";
    kind = "networking";
    requires = {
      features = [ "containers" ];
      services = [
        "caddy"
        "gluetun"
      ];
      domain = true;
    };
  };

  caddy = {
    description = "Public ingress proxy";
    kind = "ingress";
    public = true;
    stateful = true;
    requires = {
      features = [ "containers" ];
      secrets = true;
      domain = true;
    };
  };

  camofox = {
    description = "Camofox browser automation service";
    requires.features = [ "containers" ];
    stateful = true;
  };

  codeforge-mcp = {
    description = "CodeForge MCP coding workspace runtime";
    kind = "application";
    public = true;
    stateful = true;
    requires = {
      features = [ "containers" ];
      services = [ "caddy" ];
      secrets = true;
      domain = true;
    };
  };

  databasus = {
    description = "Databasus database UI";
    requires.features = [ "containers" ];
    stateful = true;
  };

  forgejo = {
    description = "Git hosting";
    kind = "application";
    public = true;
    stateful = true;
    requires = {
      features = [ "containers" ];
      services = [
        "caddy"
        "pgdog"
      ];
      secrets = true;
      domain = true;
    };
  };

  gluetun = {
    description = "VPN proxy container";
    kind = "networking";
    stateful = true;
    requires = {
      features = [ "containers" ];
      secrets = true;
    };
  };

  hermes = {
    description = "Hermes agent gateway";
    requires = {
      features = [ "containers" ];
      services = [ "camofox" ];
    };
  };

  openchamber = {
    description = "OpenChamber web application and OpenCode service";
    public = true;
    requires = {
      features = [ "ai" ];
      services = [ "caddy" ];
      domain = true;
    };
  };

  pgdog = {
    description = "PostgreSQL connection pooler";
    kind = "platform";
    requires = {
      features = [ "containers" ];
      services = [ "postgres" ];
    };
  };

  postgres = {
    description = "Shared PostgreSQL database";
    kind = "database";
    stateful = true;
    requires = {
      features = [ "containers" ];
      secrets = true;
    };
  };

  redis = {
    description = "Shared Redis cache";
    kind = "cache";
    stateful = true;
    requires = {
      features = [ "containers" ];
      secrets = true;
    };
  };

  restic = {
    description = "Restic backups";
    kind = "backup";
    stateful = true;
    requires = {
      features = [ "containers" ];
      secrets = true;
    };
  };

  siyuan = {
    description = "SiYuan notes service";
    public = true;
    stateful = true;
    requires = {
      features = [ "containers" ];
      services = [ "caddy" ];
      domain = true;
    };
  };

  vaultwarden = {
    description = "Password manager";
    public = true;
    stateful = true;
    requires = {
      features = [ "containers" ];
      services = [
        "caddy"
        "postgres"
      ];
      secrets = true;
      domain = true;
    };
  };
}
