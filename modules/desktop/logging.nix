{ ... }:

{
  # Monitoring configuration
  services = {
    prometheus = {
      enable = true;
      port = 9001;
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
      };
    };

    fluent-bit = {
      enable = true;
      settings = {
        service = {
          flush = 1;
          log_level = "info";
        };
        pipeline.outputs = [
          {
            name = "loki";
            match = "journal";
            host = "server";
            port = 3090;
            labels = "job=systemd-journal,host=$hostname,unit=$unit";
            line_format = "json";
          }
        ];
      };
    };
  };

  # Open port for Loki
  networking.firewall.allowedTCPPorts = [ 9002 ];
}
