{
  mkNginxVhost,
  ...
}:

{
  services.mealie = {
    enable = true;
    port = 9000;
    settings = {
      OPENAI_BASE_URL = "http://127.0.0.1:8081/v1";
      OPENAI_API_KEY = "local-only";
      OPENAI_MODEL = "qwen-3.5-9b-task";
    };
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "mealie.homehub.tv";
    port = 9000;
  };
}
