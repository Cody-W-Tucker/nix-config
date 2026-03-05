{
  programs.opencode.skills = {
    obsidian-cli = ''
      ---
      name: obsidian-cli
      description: Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, and more. Also supports plugin and theme development with commands to reload plugins, run JavaScript, capture errors, take screenshots, and inspect the DOM. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, perform vault operations from the command line, or develop and debug Obsidian plugins and themes.
      ---

      # Obsidian CLI

      Use the `obsidian` CLI to interact with a running Obsidian instance. Requires Obsidian to be open.

      ## Command reference

      Run `obsidian help` to see all available commands. This is always up to date. Full docs: https://help.obsidian.md/cli

      ## Syntax

      **Parameters** take a value with `=`. Quote values with spaces:

      ```bash
      obsidian create name="My Note" content="Hello world"
      ```

      **Flags** are boolean switches with no value:

      ```bash
      obsidian create name="My Note" silent overwrite
      ```

      For multiline content use `\n` for newline and `\t` for tab.

      ## File targeting

      Many commands accept `file` or `path` to target a file. Without either, the active file is used.

      - `file=<name>` — resolves like a wikilink (name only, no path or extension needed)
      - `path=<path>` — exact path from vault root, e.g. `folder/note.md`

      ## Vault targeting

      Commands target the most recently focused vault by default. Use `vault=<name>` as the first parameter to target a specific vault:

      ```bash
      obsidian vault="My Vault" search query="test"
      ```

      ## Common patterns

      ```bash
      obsidian read file="My Note"
      obsidian create name="New Note" content="# Hello" template="Template" silent
      obsidian append file="My Note" content="New line"
      obsidian search query="search term" limit=10
      obsidian daily:read
      obsidian daily:append content="- [ ] New task"
      obsidian property:set name="status" value="done" file="My Note"
      obsidian tasks daily todo
      obsidian tags sort=count counts
      obsidian backlinks file="My Note"
      ```

      Use `--copy` on any command to copy output to clipboard. Use `silent` to prevent files from opening. Use `total` on list commands to get a count.

      ## Plugin development

      ### Develop/test cycle

      After making code changes to a plugin or theme, follow this workflow:

      1. **Reload** the plugin to pick up changes:
         ```bash
         obsidian plugin:reload id=my-plugin
         ```
      2. **Check for errors** — if errors appear, fix and repeat from step 1:
         ```bash
         obsidian dev:errors
         ```
      3. **Verify visually** with a screenshot or DOM inspection:
         ```bash
         obsidian dev:screenshot path=screenshot.png
         obsidian dev:dom selector=".workspace-leaf" text
         ```
      4. **Check console output** for warnings or unexpected logs:
         ```bash
         obsidian dev:console level=error
         ```

      ### Additional developer commands

      Run JavaScript in the app context:

      ```bash
      obsidian eval code="app.vault.getFiles().length"
      ```

      Inspect CSS values:

      ```bash
      obsidian dev:css selector=".workspace-leaf" prop=background-color
      ```

      Toggle mobile emulation:

      ```bash
      obsidian dev:mobile on
      ```

      Run `obsidian help` to see additional developer commands including CDP and debugger controls.
    '';
    obsidian-markdown = ''
      ---
      name: obsidian-markdown
      description: Create and edit Obsidian Flavored Markdown with wikilinks, embeds, callouts, properties, and other Obsidian-specific syntax. Use when working with .md files in Obsidian, or when the user mentions wikilinks, callouts, frontmatter, tags, embeds, or Obsidian notes.
      ---

      # Obsidian Flavored Markdown Skill

      Create and edit valid Obsidian Flavored Markdown. Obsidian extends CommonMark and GFM with wikilinks, embeds, callouts, properties, comments, and other syntax. This skill covers only Obsidian-specific extensions -- standard Markdown (headings, bold, italic, lists, quotes, code blocks, tables) is assumed knowledge.

      ## Workflow: Creating an Obsidian Note

      1. **Add frontmatter** with properties (title, tags, aliases) at the top of the file.
      2. **Write content** using standard Markdown for structure, plus Obsidian-specific syntax below.
      3. **Link related notes** using wikilinks (`[[Note]]`) for internal vault connections, or standard Markdown links for external URLs.
      4. **Embed content** from other notes, images, or PDFs using the `![[embed]]` syntax.
      5. **Add callouts** for highlighted information using `> [!type]` syntax.
      6. **Verify** the note renders correctly in Obsidian's reading view.

      > When choosing between wikilinks and Markdown links: use `[[wikilinks]]` for notes within the vault (Obsidian tracks renames automatically) and `[text](url)` for external URLs only.

      ## Internal Links (Wikilinks)

      ```markdown
      [[Note Name]]                          Link to note
      [[Note Name|Display Text]]             Custom display text
      [[Note Name#Heading]]                  Link to heading
      [[Note Name#^block-id]]                Link to block
      [[#Heading in same note]]              Same-note heading link
      ```

      Define a block ID by appending `^block-id` to any paragraph:

      ```markdown
      This paragraph can be linked to. ^my-block-id
      ```

      For lists and quotes, place the block ID on a separate line after the block:

      ```markdown
      > A quote block

      ^quote-id
      ```

      ## Embeds

      Prefix any wikilink with `!` to embed its content inline:

      ```markdown
      ![[Note Name]]                         Embed full note
      ![[Note Name#Heading]]                 Embed section
      ![[image.png]]                         Embed image
      ![[image.png|300]]                     Embed image with width
      ![[document.pdf#page=3]]               Embed PDF page
      ```

      ## Callouts

      ```markdown
      > [!note]
      > Basic callout.

      > [!warning] Custom Title
      > Callout with a custom title.

      > [!faq]- Collapsed by default
      > Foldable callout (- collapsed, + expanded).
      ```

      Common types: `note`, `tip`, `warning`, `info`, `example`, `quote`, `bug`, `danger`, `success`, `failure`, `question`, `abstract`, `todo`.

      ## Properties (Frontmatter)

      ```yaml
      ---
      title: My Note
      date: 2024-01-15
      tags:
        - project
        - active
      aliases:
        - Alternative Name
      cssclasses:
        - custom-class
      ---
      ```

      Default properties: `tags` (searchable labels), `aliases` (alternative note names for link suggestions), `cssclasses` (CSS classes for styling).

      ## Tags

      ```markdown
      #tag                    Inline tag
      #nested/tag             Nested tag with hierarchy
      ```

      Tags can contain letters, numbers (not first character), underscores, hyphens, and forward slashes. Tags can also be defined in frontmatter under the `tags` property.

      ## Comments

      ```markdown
      This is visible %%but this is hidden%% text.

      %%
      This entire block is hidden in reading view.
      %%
      ```

      ## Obsidian-Specific Formatting

      ```markdown
      ==Highlighted text==                   Highlight syntax
      ```

      ## Math (LaTeX)

      ```markdown
      Inline: $e^{i\pi} + 1 = 0$

      Block:
      $$
      \frac{a}{b} = c
      $$
      ```

      ## Diagrams (Mermaid)

      ````markdown
      ```mermaid
      graph TD
          A[Start] --> B{Decision}
          B -->|Yes| C[Do this]
          B -->|No| D[Do that]
      ```
      ````

      To link Mermaid nodes to Obsidian notes, add `class NodeName internal-link;`.

      ## Footnotes

      ```markdown
      Text with a footnote[^1].

      [^1]: Footnote content.

      Inline footnote.^[This is inline.]
      ```

      ## Complete Example

      ````markdown
      ---
      title: Project Alpha
      date: 2024-01-15
      tags:
        - project
        - active
      status: in-progress
      ---

      # Project Alpha

      This project aims to [[improve workflow]] using modern techniques.

      > [!important] Key Deadline
      > The first milestone is due on ==January 30th==.

      ## Tasks

      - [x] Initial planning
      - [ ] Development phase
        - [ ] Backend implementation
        - [ ] Frontend design

      ## Notes

      The algorithm uses $O(n \log n)$ sorting. See [[Algorithm Notes#Sorting]] for details.

      ![[Architecture Diagram.png|600]]

      Reviewed in [[Meeting Notes 2024-01-10#Decisions]].
      ````

      ## References

      - [Obsidian Flavored Markdown](https://help.obsidian.md/obsidian-flavored-markdown)
      - [Internal links](https://help.obsidian.md/links)
      - [Embed files](https://help.obsidian.md/embeds)
      - [Callouts](https://help.obsidian.md/callouts)
      - [Properties](https://help.obsidian.md/properties)
    '';
  };
}
