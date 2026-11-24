{ lib, ... }:
let
  # Agency service catalog IDs (Services/services.json) and the job each one delivers.
  # Keep IDs in step with the catalog; editing any text starts a new dataset.
  services = {
    seo = "search engines and AI assistants crawl, index and rank the client's site for priority queries";
    paid-media = "Google, Meta and LinkedIn ad spend run to a target cost per qualified lead or acquisition";
    social-media = "an organic social calendar of approved posts in the client's voice, with monthly readouts";
    content-marketing = "an editorial program of evidence-backed articles, pages or videos that convert";
    email-marketing = "lifecycle flows and campaigns sent to an opted-in list, with deliverability kept healthy";
    cro = "prioritized, evidence-backed changes to a conversion surface such as a landing page or checkout";
    web-design = "a new or redesigned website that keeps its URLs, works on every device and converts";
    analytics = "KPIs and conversion events tracked correctly and reported monthly against a baseline";
    lead-generation = "outbound email to an evidence-qualified prospect list that books qualified meetings";
    public-relations = "earned press coverage in target outlets from approved pitches";
    influencer-marketing = "paid, gifted or affiliate creator placements with disclosure and tracked outcomes";
    marketing-strategy = "a sequenced marketing plan built on market, competitor and customer evidence";
    account-management = "client reporting, commitments, scope decisions and renewal";
    workflow-enablement = "one recurring client job run as an agent workflow inside the client's own tools";
  };
in
{
  # A saved bookmark (title, url, type, Karakeep summary) is the state. One yes/no question
  # per service; harvest ledgers label only the services that triaged it.
  services.laya.classifiers.service-routing = {
    questions = lib.mapAttrs (_: job: {
      type = "noul";
      instructions = "Is this saved source worth inspecting as a method, tool or worked example for an agency service that delivers ${job}?";
    }) services;
    learnFromTeacher = true;
    # Harvest agents read each imported source in full; the fallback sees only the summary.
    calibrateOn = [
      "human"
      "imported"
    ];
  };

  # Same bookmark state: what kind of source it is, and whether CodyOS should evaluate it.
  services.laya.classifiers.bookmark-kind = {
    questions = {
      method = {
        type = "noul";
        instructions = "Does this source teach a method, process or worked example a practitioner could follow?";
      };
      capability = {
        type = "noul";
        instructions = "Is this source a tool, library, service, model or agent skill that could be installed or called?";
      };
      codyos = {
        type = "noul";
        instructions = "Does this bookmark give enough evidence to identify a specific tool, capability, or practice that would advance at least one CodyOS goal: self-hosted services, composable system capabilities, local model use, or agents testing changes before a human approves deployment? Answer yes only if you can identify both what CodyOS could adopt or adapt and what it would improve. A design pattern can qualify without anything to install. Sharing the same topics is not enough. A yes flags a candidate for review, not a recommendation to adopt it.";
      };
    };
    learnFromTeacher = true;
  };
}
