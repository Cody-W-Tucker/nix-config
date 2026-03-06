{
  programs.opencode.skills = {
    obsidian-cli = ''
      ---
      name: obsidian-cli
      description: Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, and more. Also supports plugin and theme development with commands to reload plugins, run JavaScript, capture errors, take screenshots, and inspect the DOM. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, perform vault operations from the command line, or develop and debug Obsidian plugins and themes.
      ---

      # Obsidian CLI

      Requirements: You must use the obsidian CLI when making changes to files. Traditional file I/O will not trigger Obsidian's internal events, so changes won't appear in the app until you manually reload or interact with the file. The obsidian CLI ensures all changes are immediately reflected in the app and trigger any relevant plugins or views.

      Memory: The user's primary vault is named "Personal".

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
    obsidian-bases = ''
      ---
      name: obsidian-bases
      description: Create and edit Obsidian Bases (.base files) with views, filters, formulas, and summaries. Use when working with .base files, creating database-like views of notes, or when the user mentions Bases, table views, card views, filters, or formulas in Obsidian.
      ---

      # Obsidian Bases Skill

      Requirements: You must use the obsidian CLI when making changes to files. Traditional file I/O will not trigger Obsidian's internal events, so changes won't appear in the app until you manually reload or interact with the file. The obsidian CLI ensures all changes are immediately reflected in the app and trigger any relevant plugins or views.

      ## Workflow

      1. **Create the file**: Create a `.base` file in the vault with valid YAML content
      2. **Define scope**: Add `filters` to select which notes appear (by tag, folder, property, or date)
      3. **Add formulas** (optional): Define computed properties in the `formulas` section
      4. **Configure views**: Add one or more views (`table`, `cards`, `list`, or `map`) with `order` specifying which properties to display
      5. **Validate**: Verify the file is valid YAML with no syntax errors. Check that all referenced properties and formulas exist. Common issues: unquoted strings containing special YAML characters, mismatched quotes in formula expressions, referencing `formula.X` without defining `X` in `formulas`
      6. **Test in Obsidian**: Open the `.base` file in Obsidian to confirm the view renders correctly. If it shows a YAML error, check quoting rules below

      ## Schema

      Base files use the `.base` extension and contain valid YAML.

      ```yaml
      # Global filters apply to ALL views in the base
      filters:
        # Can be a single filter string
        # OR a recursive filter object with and/or/not
        and: []
        or: []
        not: []

      # Define formula properties that can be used across all views
      formulas:
        formula_name: 'expression'

      # Configure display names and settings for properties
      properties:
        property_name:
          displayName: "Display Name"
        formula.formula_name:
          displayName: "Formula Display Name"
        file.ext:
          displayName: "Extension"

      # Define custom summary formulas
      summaries:
        custom_summary_name: 'values.mean().round(3)'

      # Define one or more views
      views:
        - type: table | cards | list | map
          name: "View Name"
          limit: 10                    # Optional: limit results
          groupBy:                     # Optional: group results
            property: property_name
            direction: ASC | DESC
          filters:                     # View-specific filters
            and: []
          order:                       # Properties to display in order
            - file.name
            - property_name
            - formula.formula_name
          summaries:                   # Map properties to summary formulas
            property_name: Average
      ```

      ## Filter Syntax

      Filters narrow down results. They can be applied globally or per-view.

      ### Filter Structure

      ```yaml
      # Single filter
      filters: 'status == "done"'

      # AND - all conditions must be true
      filters:
        and:
          - 'status == "done"'
          - 'priority > 3'

      # OR - any condition can be true
      filters:
        or:
          - 'file.hasTag("book")'
          - 'file.hasTag("article")'

      # NOT - exclude matching items
      filters:
        not:
          - 'file.hasTag("archived")'

      # Nested filters
      filters:
        or:
          - file.hasTag("tag")
          - and:
              - file.hasTag("book")
              - file.hasLink("Textbook")
          - not:
              - file.hasTag("book")
              - file.inFolder("Required Reading")
      ```

      ### Filter Operators

      | Operator | Description |
      |----------|-------------|
      | `==` | equals |
      | `!=` | not equal |
      | `>` | greater than |
      | `<` | less than |
      | `>=` | greater than or equal |
      | `<=` | less than or equal |
      | `&&` | logical and |
      | `\|\|` | logical or |
      | <code>!</code> | logical not |

      ## Properties

      ### Three Types of Properties

      1. **Note properties** - From frontmatter: `note.author` or just `author`
      2. **File properties** - File metadata: `file.name`, `file.mtime`, etc.
      3. **Formula properties** - Computed values: `formula.my_formula`

      ### File Properties Reference

      | Property | Type | Description |
      |----------|------|-------------|
      | `file.name` | String | File name |
      | `file.basename` | String | File name without extension |
      | `file.path` | String | Full path to file |
      | `file.folder` | String | Parent folder path |
      | `file.ext` | String | File extension |
      | `file.size` | Number | File size in bytes |
      | `file.ctime` | Date | Created time |
      | `file.mtime` | Date | Modified time |
      | `file.tags` | List | All tags in file |
      | `file.links` | List | Internal links in file |
      | `file.backlinks` | List | Files linking to this file |
      | `file.embeds` | List | Embeds in the note |
      | `file.properties` | Object | All frontmatter properties |

      ### The `this` Keyword

      - In main content area: refers to the base file itself
      - When embedded: refers to the embedding file
      - In sidebar: refers to the active file in main content

      ## Formula Syntax

      Formulas compute values from properties. Defined in the `formulas` section.

      ```yaml
      formulas:
        # Simple arithmetic
        total: "price * quantity"

        # Conditional logic
        status_icon: 'if(done, "✅", "⏳")'

        # String formatting
        formatted_price: 'if(price, price.toFixed(2) + " dollars")'

        # Date formatting
        created: 'file.ctime.format("YYYY-MM-DD")'

        # Calculate days since created (use .days for Duration)
        days_old: '(now() - file.ctime).days'

        # Calculate days until due date
        days_until_due: 'if(due_date, (date(due_date) - today()).days, "")'
      ```

      ## Key Functions

      Most commonly used functions. For the complete reference of all types (Date, String, Number, List, File, Link, Object, RegExp), see [FUNCTIONS_REFERENCE.md](references/FUNCTIONS_REFERENCE.md).

      | Function | Signature | Description |
      |----------|-----------|-------------|
      | `date()` | `date(string): date` | Parse string to date (`YYYY-MM-DD HH:mm:ss`) |
      | `now()` | `now(): date` | Current date and time |
      | `today()` | `today(): date` | Current date (time = 00:00:00) |
      | `if()` | `if(condition, trueResult, falseResult?)` | Conditional |
      | `duration()` | `duration(string): duration` | Parse duration string |
      | `file()` | `file(path): file` | Get file object |
      | `link()` | `link(path, display?): Link` | Create a link |

      ### Duration Type

      When subtracting two dates, the result is a **Duration** type (not a number).

      **Duration Fields:** `duration.days`, `duration.hours`, `duration.minutes`, `duration.seconds`, `duration.milliseconds`

      **IMPORTANT:** Duration does NOT support `.round()`, `.floor()`, `.ceil()` directly. Access a numeric field first (like `.days`), then apply number functions.

      ```yaml
      # CORRECT: Calculate days between dates
      "(date(due_date) - today()).days"                    # Returns number of days
      "(now() - file.ctime).days"                          # Days since created
      "(date(due_date) - today()).days.round(0)"           # Rounded days

      # WRONG - will cause error:
      # "((date(due) - today()) / 86400000).round(0)"      # Duration doesn't support division then round
      ```

      ### Date Arithmetic

      ```yaml
      # Duration units: y/year/years, M/month/months, d/day/days,
      #                 w/week/weeks, h/hour/hours, m/minute/minutes, s/second/seconds
      "now() + \"1 day\""       # Tomorrow
      "today() + \"7d\""        # A week from today
      "now() - file.ctime"      # Returns Duration
      "(now() - file.ctime).days"  # Get days as number
      ```

      ## View Types

      ### Table View

      ```yaml
      views:
        - type: table
          name: "My Table"
          order:
            - file.name
            - status
            - due_date
          summaries:
            price: Sum
            count: Average
      ```

      ### Cards View

      ```yaml
      views:
        - type: cards
          name: "Gallery"
          order:
            - file.name
            - cover_image
            - description
      ```

      ### List View

      ```yaml
      views:
        - type: list
          name: "Simple List"
          order:
            - file.name
            - status
      ```

      ### Map View

      Requires latitude/longitude properties and the Maps community plugin.

      ```yaml
      views:
        - type: map
          name: "Locations"
          # Map-specific settings for lat/lng properties
      ```

      ## Default Summary Formulas

      | Name | Input Type | Description |
      |------|------------|-------------|
      | `Average` | Number | Mathematical mean |
      | `Min` | Number | Smallest number |
      | `Max` | Number | Largest number |
      | `Sum` | Number | Sum of all numbers |
      | `Range` | Number | Max - Min |
      | `Median` | Number | Mathematical median |
      | `Stddev` | Number | Standard deviation |
      | `Earliest` | Date | Earliest date |
      | `Latest` | Date | Latest date |
      | `Range` | Date | Latest - Earliest |
      | `Checked` | Boolean | Count of true values |
      | `Unchecked` | Boolean | Count of false values |
      | `Empty` | Any | Count of empty values |
      | `Filled` | Any | Count of non-empty values |
      | `Unique` | Any | Count of unique values |

      ## Complete Examples

      ### Task Tracker Base

      ```yaml
      filters:
        and:
          - file.hasTag("task")
          - 'file.ext == "md"'

      formulas:
        days_until_due: 'if(due, (date(due) - today()).days, "")'
        is_overdue: 'if(due, date(due) < today() && status != "done", false)'
        priority_label: 'if(priority == 1, "🔴 High", if(priority == 2, "🟡 Medium", "🟢 Low"))'

      properties:
        status:
          displayName: Status
        formula.days_until_due:
          displayName: "Days Until Due"
        formula.priority_label:
          displayName: Priority

      views:
        - type: table
          name: "Active Tasks"
          filters:
            and:
              - 'status != "done"'
          order:
            - file.name
            - status
            - formula.priority_label
            - due
            - formula.days_until_due
          groupBy:
            property: status
            direction: ASC
          summaries:
            formula.days_until_due: Average

        - type: table
          name: "Completed"
          filters:
            and:
              - 'status == "done"'
          order:
            - file.name
            - completed_date
      ```

      ### Reading List Base

      ```yaml
      filters:
        or:
          - file.hasTag("book")
          - file.hasTag("article")

      formulas:
        reading_time: 'if(pages, (pages * 2).toString() + " min", "")'
        status_icon: 'if(status == "reading", "📖", if(status == "done", "✅", "📚"))'
        year_read: 'if(finished_date, date(finished_date).year, "")'

      properties:
        author:
          displayName: Author
        formula.status_icon:
          displayName: ""
        formula.reading_time:
          displayName: "Est. Time"

      views:
        - type: cards
          name: "Library"
          order:
            - cover
            - file.name
            - author
            - formula.status_icon
          filters:
            not:
              - 'status == "dropped"'

        - type: table
          name: "Reading List"
          filters:
            and:
              - 'status == "to-read"'
          order:
            - file.name
            - author
            - pages
            - formula.reading_time
      ```

      ### Daily Notes Index

      ```yaml
      filters:
        and:
          - file.inFolder("Daily Notes")
          - '/^\d{4}-\d{2}-\d{2}$/.matches(file.basename)'

      formulas:
        word_estimate: '(file.size / 5).round(0)'
        day_of_week: 'date(file.basename).format("dddd")'

      properties:
        formula.day_of_week:
          displayName: "Day"
        formula.word_estimate:
          displayName: "~Words"

      views:
        - type: table
          name: "Recent Notes"
          limit: 30
          order:
            - file.name
            - formula.day_of_week
            - formula.word_estimate
            - file.mtime
      ```

      ## Embedding Bases

      Embed in Markdown files:

      ```markdown
      ![[MyBase.base]]

      <!-- Specific view -->
      ![[MyBase.base#View Name]]
      ```

      ## YAML Quoting Rules

      - Use single quotes for formulas containing double quotes: `'if(done, "Yes", "No")'`
      - Use double quotes for simple strings: `"My View Name"`
      - Escape nested quotes properly in complex expressions

      ## Troubleshooting

      ### YAML Syntax Errors

      **Unquoted special characters**: Strings containing `:`, `{`, `}`, `[`, `]`, `,`, `&`, `*`, `#`, `?`, `|`, `-`, `<`, `>`, `=`, `!`, `%`, `@`, `` ` `` must be quoted.

      ```yaml
      # WRONG - colon in unquoted string
      displayName: Status: Active

      # CORRECT
      displayName: "Status: Active"
      ```

      **Mismatched quotes in formulas**: When a formula contains double quotes, wrap the entire formula in single quotes.

      ```yaml
      # WRONG - double quotes inside double quotes
      formulas:
        label: "if(done, "Yes", "No")"

      # CORRECT - single quotes wrapping double quotes
      formulas:
        label: 'if(done, "Yes", "No")'
      ```

      ### Common Formula Errors

      **Duration math without field access**: Subtracting dates returns a Duration, not a number. Always access `.days`, `.hours`, etc.

      ```yaml
      # WRONG - Duration is not a number
      "(now() - file.ctime).round(0)"

      # CORRECT - access .days first, then round
      "(now() - file.ctime).days.round(0)"
      ```

      **Missing null checks**: Properties may not exist on all notes. Use `if()` to guard.

      ```yaml
      # WRONG - crashes if due_date is empty
      "(date(due_date) - today()).days"

      # CORRECT - guard with if()
      'if(due_date, (date(due_date) - today()).days, "")'
      ```

      **Referencing undefined formulas**: Ensure every `formula.X` in `order` or `properties` has a matching entry in `formulas`.

      ```yaml
      # This will fail silently if 'total' is not defined in formulas
      order:
        - formula.total

      # Fix: define it
      formulas:
        total: "price * quantity"
      ```

      ## References

      - [Bases Syntax](https://help.obsidian.md/bases/syntax)
      - [Functions](https://help.obsidian.md/bases/functions)
      - [Views](https://help.obsidian.md/bases/views)
      - [Formulas](https://help.obsidian.md/formulas)
    '';
  };
}
