# Open Ontologies

Use the open-ontologies MCP server for RDF/OWL ontology files, SPARQL queries,
SHACL validation, graph reasoning, and graph-based retrieval. Use existing note
search or code-review-graph tools instead for ordinary notes or code searches.

Load an ontology before querying or reasoning. The graph is in memory: it is
local to the server process, is not shared between OpenCode and Hermes, and is
lost when the server exits. Loading, clearing, and reasoning can change the
working graph; do not treat them as read-only. Ask before changing an existing
graph or writing over a user's ontology.

The Rust engine may generate certificates, but the separate Lean checkers are
not installed by this integration. Do not claim independent verification
unless a checker was actually run and accepted the certificate. SQL, embedding,
and plugin tools are not enabled in this build.
