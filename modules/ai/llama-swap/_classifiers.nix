_:
let
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
    workflow-enablement = "one of a client's recurring business jobs run as an agent workflow inside the client's own tools; not tooling for running one's own servers, models or agents";
  };
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
  services.laya.classifiers.bookmark-route = distill // {
    questions.route = {
      type = "choice";
      instructions = "Which one agency service is this saved source most worth inspecting for, as a method, tool or worked example for delivering that service to a client? Each service is named by the job it delivers for a client. Choose the single best fit. Answer none if no service clearly fits; sharing a topic is not enough.";
      criteria = services // {
        none = "no agency service clearly fits";
      };
    };
    questions.codyos = {
      type = "noul";
      instructions = "Could CodyOS adopt or adapt something specific from this saved source? CodyOS is a self-hosted personal operating system: self-hosted services, composable system capabilities, local models, and agents that test changes before a human approves deployment. Answer yes only if you can name both what CodyOS would borrow (a tool, capability or practice; a design pattern counts with nothing to install) and what it would improve. Sharing a topic is not enough. Yes means worth reviewing, not worth adopting. Answer regardless of whether it also fits an agency service.";
    };
  };
}
