{ den, ... }:
{
  den.aspects.ollama = {
    includes = [ den.aspects.oci-base den.aspects.container-network ];
    nixos = { lib, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "ollama" ];
      virtualisation.oci-containers.containers.ollama = lib.dot.mkOci "ollama" {
        image = "ollama/ollama:latest";
        volumes = [ "${lib.dot.containerDataDir "ollama"}:/root/.ollama" ];
        ports = [ "127.0.0.1:11434:11434" ];
      };
      systemd.services.podman-ollama = lib.dot.mkContainerDeps "ollama";
    };
  };

  den.aspects.open-webui = {
    includes = [ den.aspects.oci-base den.aspects.container-network den.aspects.ollama ];
    nixos = { lib, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "open-webui" ];
      virtualisation.oci-containers.containers.open-webui = lib.dot.mkOci "open-webui" {
        image = "ghcr.io/open-webui/open-webui:main";
        environment = {
          OLLAMA_BASE_URL = "http://ollama:11434";
        };
        volumes = [ "${lib.dot.containerDataDir "open-webui"}:/app/backend/data" ];
        ports = [ "127.0.0.1:8088:8080" ];
        dependsOn = [ "ollama" ];
      };
      systemd.services.podman-open-webui = lib.dot.mkContainerDeps "open-webui" // {
        after = [ "podman-network-${lib.dot.containerNetwork}.service" "podman-ollama.service" ];
        requires = [ "podman-network-${lib.dot.containerNetwork}.service" "podman-ollama.service" ];
      };
    };
  };
}
