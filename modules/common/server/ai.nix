{ config, pkgs, ... }:

{
  # Ollama local llm
  services.ollama = {
    enable = true;
  };
}
