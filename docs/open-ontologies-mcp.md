# Open Ontologies

Use the open-ontologies MCP server for RDF/OWL ontology files, SPARQL queries,
SHACL validation, graph reasoning, and graph-based retrieval. Use existing note
search or code-review-graph tools instead for ordinary notes or code searches.

The NAS hosts one persistent graph at `/mnt/knowledge/.open-ontologies`.
OpenCode on Beast and the NAS and Hermes on the NAS share it. The MCP endpoint on Beast's
Tailscale connection is restricted to Beast's Tailscale address; the NAS-local
HTTP API is not authenticated. Other local users with access to the endpoint
can read and change the graph. Do not open the database with a second process.

Loading, clearing, and reasoning can change the shared graph; do not treat them
as read-only. Ask before changing an existing graph or writing over a user's
ontology. Paths supplied to the server refer to the NAS filesystem.

**Backup limitation:** the live database directory is excluded from Restic
because copying its changing RocksDB and SQLite files is not a consistent
backup. Until a database-aware backup is configured and tested, export important
ontologies separately and do not rely on the NAS backup to recover this graph.

The Rust engine may generate certificates, but the separate Lean checkers are
not installed by this integration. Do not claim independent verification
unless a checker was actually run and accepted the certificate. SQL, embedding,
and plugin tools are not enabled in this build.
