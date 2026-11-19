{ nasTailscale }:
let
  localHost = "127.0.0.1";
  localPort = 8888;
  local = "http://${localHost}:${toString localPort}";
  tailnetPort = 18083;
in
{
  inherit
    local
    localHost
    localPort
    tailnetPort
    ;
  api = localAi: if localAi then local else "http://${nasTailscale}:${toString tailnetPort}";
}
