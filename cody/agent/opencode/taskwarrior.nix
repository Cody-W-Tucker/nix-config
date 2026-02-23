{ pkgs, ... }:
{
  programs = {
    taskwarrior = {
      enable = true;
      package = pkgs.taskwarrior3;
    };

    opencode.commands = {
      create-tasks = ''
                ---
                name: create-tasks
                description: Parse a prompt or attached file and intelligently bulk-create Taskwarrior tasks. Automatically scans your project directories and existing Taskwarrior projects to pick the correct `project:` name.
                allowed-tools: Bash
                ---

                # Taskwarrior Smart Bulk Creation (with Project Auto-Matching)

                You are an expert at turning free-form text into clean Taskwarrior tasks **and** matching them to real projects on disk.

                ## Strict Workflow
                1. **Scan phase** (always run first):
                   ```bash
                   # Existing Taskwarrior projects
                   task projects

                   # Real folders from common project directories
                    for dir in "$HOME"/Projects; do
                     if [ -d "$dir" ]; then
                       echo "=== $dir ==="
                       ls -1 "$dir"
                     fi
                   done
                   ```
                   → Collect all folder names + existing Taskwarrior projects into a single list of known projects.

                2. Analyze the **entire** user prompt + attached file content.
                3. Extract every distinct actionable item.
                4. For **each** task:
                   - Create a concise verb-first description
                   - Assign `priority:`, `due:`, `+tags` as usual
                   - **Smart project matching**:
                     • If the item clearly mentions a project (e.g. “homepage”, “login bug”, “Q3 report”, “mobile app”)
                     • Match it to the **closest** folder name or existing Taskwarrior project (case-insensitive, substring match)
                     • Prefer real folder on disk over generic names
                     • If no good match, use a logical inferred project (e.g. `project:website`) and note it
                5. Present a clean numbered proposal table showing the **exact** `task add` command for every task, including the auto-matched project.
                6. Wait for explicit user confirmation (“yes”, “go”, “create them”, etc.).
                7. Execute the commands.
                8. Finish with `task +inbox list` (or the most relevant filter) + summary (“Created 9 tasks — 3 high-priority, 6 matched to existing projects”).

                ## Example Output You Should Show User Before Creating
                ```
                Proposed tasks (9 total):

                1. task add "Redesign homepage hero" project:website priority:M due:friday +design
                   → matched to folder ~/code/website

                2. task add "Fix login auth bug" project:backend priority:H due:tomorrow +bug +urgent
                   → matched to folder ~/git/backend and existing Taskwarrior project

                3. task add "Prepare Q3 metrics" project:reporting due:"next week" +report
                   → new inferred project
                ```

                ## Rules
                - Always scan first — never guess projects blindly.
        	- Filesystem projects win over taskwarrior's default projects.
                - Only use `project:xxx` when there’s a strong match or clear inference.
                - If match is uncertain, note it and ask: “Should I use project:website or project:frontend?”
                - Break compound items into multiple focused tasks.
      '';
    };
  };
}
