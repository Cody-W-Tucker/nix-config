# Skill catalog

Store agent instructions as complete `<category>/<skill-id>/SKILL.md` directories.
Keep supporting files in the same directory. To import from another repository,
copy the whole selected folder and record the upstream URL, commit, and source
path in the commit message. Keep upstream licenses and review scripts as code.

Adding a folder does not load it anywhere. The Den feature that makes a tool
available points its existing harness adapter at the folder or pack. A skill
that ships with a tool should normally come from the tool's own pinned source,
not from a second copy here. Standalone skills can be selected as a collection
without coupling them to a tool.
