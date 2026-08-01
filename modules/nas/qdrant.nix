{ mkNginxVhost, ... }:

{
  services.nginx.virtualHosts = mkNginxVhost {
    host = "qdrant.homehub.tv";
    locations = {
      # HTTP API (REST API on port 6333)
      "/" = {
        proxyPass = "http://localhost:6333";
      };
      # gRPC API (on port 6334)
      "/grpc" = {
        proxyPass = "http://localhost:6334";
        extraConfig = ''
          grpc_set_header Host $host;
          grpc_set_header X-Real-IP $remote_addr;
          grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          grpc_pass grpc://localhost:6334;
        '';
      };
    };
  };
}
