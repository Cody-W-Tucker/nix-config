{ inputs, ... }:
{
  # Zen Browser as the default browser.
  den.aspects.browser.provides.to-users.homeManager = {
    imports = [ inputs.zen-browser.homeModules.beta ];

    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;
    };
  };
}
