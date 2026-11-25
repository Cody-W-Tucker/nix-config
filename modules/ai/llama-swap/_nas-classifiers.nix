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
  # Vega distils Jev and the user's Karakeep list edits: both train it, and a fifth of bookmarks
  # is held out to check Vega against them before it answers alone.
  distill = {
    learnFromTeacher = true;
    calibrateOn = [
      "human"
      "imported"
      "teacher"
    ];
    calibrationShare = 0.2;
  };
in
{
  # A saved bookmark (title, url, type, Karakeep summary) is the state. One choice per bookmark,
  # so Vega either routes it alone or the whole bookmark goes to Jev. CodyOS is one more route.
  services.laya.classifiers.bookmark-route = distill // {
    questions.route = {
      type = "choice";
      instructions = "Which one destination is this saved source most worth inspecting for, as a method, tool or worked example? Each agency service is named by the job it delivers. Choose the single best fit. Answer none if no destination clearly fits; sharing a topic is not enough.";
      criteria = services // {
        codyos = "CodyOS, a self-hosted personal operating system: a specific tool, capability or practice it could adopt or adapt to improve its self-hosted services, composable system capabilities, local model use, or agents testing changes before a human approves deployment";
        none = "no destination clearly fits";
      };
    };
  };
}
