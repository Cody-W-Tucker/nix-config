{
  config.services.hermes-agent = {
    settings.web = {
      search_backend = "xai";
      extract_backend = "firecrawl";
      crawl_backend = "firecrawl";
    };
  };
}
