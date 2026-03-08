// RTK Plugin - Intercepts bash commands and rewrites them to use rtk
// Single file version to avoid import issues

/** Env-var prefix pattern: \`FOO=bar BAZ=qux \` */
const ENV_PREFIX_RE = /^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)+/

/**
 * Command rewrite rules. Each entry maps a regex pattern (matched against the
 * first command in a pipeline) to a function that rewrites the full command
 * string through RTK.
 */
const RULES = [
  // --- Git ---
  [/^git\s+status(\s|$)/, (c) => c.replace(/^git status/, "rtk git status")],
  [/^git\s+diff(\s|$)/, (c) => c.replace(/^git diff/, "rtk git diff")],
  [/^git\s+log(\s|$)/, (c) => c.replace(/^git log/, "rtk git log")],
  [/^git\s+add(\s|$)/, (c) => c.replace(/^git add/, "rtk git add")],
  [/^git\s+commit(\s|$)/, (c) => c.replace(/^git commit/, "rtk git commit")],
  [/^git\s+push(\s|$)/, (c) => c.replace(/^git push/, "rtk git push")],
  [/^git\s+pull(\s|$)/, (c) => c.replace(/^git pull/, "rtk git pull")],
  [/^git\s+branch(\s|$)/, (c) => c.replace(/^git branch/, "rtk git branch")],
  [/^git\s+fetch(\s|$)/, (c) => c.replace(/^git fetch/, "rtk git fetch")],
  [/^git\s+stash(\s|$)/, (c) => c.replace(/^git stash/, "rtk git stash")],
  [/^git\s+show(\s|$)/, (c) => c.replace(/^git show/, "rtk git show")],

  // --- GitHub CLI ---
  [/^gh\s+(pr|issue|run|api|release)(\s|$)/, (c) => c.replace(/^gh /, "rtk gh ")],

  // --- Cargo (Rust) ---
  [/^cargo\s+test(\s|$)/, (c) => c.replace(/^cargo test/, "rtk cargo test")],
  [/^cargo\s+build(\s|$)/, (c) => c.replace(/^cargo build/, "rtk cargo build")],
  [/^cargo\s+clippy(\s|$)/, (c) => c.replace(/^cargo clippy/, "rtk cargo clippy")],
  [/^cargo\s+check(\s|$)/, (c) => c.replace(/^cargo check/, "rtk cargo check")],

  // --- File operations ---
  [/^cat\s+/, (c) => c.replace(/^cat /, "rtk read ")],
  [/^(rg|grep)\s+/, (c) => c.replace(/^(rg|grep) /, "rtk grep ")],
  [/^ls(\s|$)/, (c) => c.replace(/^ls/, "rtk ls")],
  [/^tree(\s|$)/, (c) => c.replace(/^tree/, "rtk tree")],
  [/^find\s+/, (c) => c.replace(/^find /, "rtk find ")],

  // --- JS/TS tooling ---
  [/^(pnpm\s+)?(npx\s+)?vitest(\s|$)/, (c) => c.replace(/^(pnpm )?(npx )?vitest( run)?/, "rtk vitest run")],
  [/^pnpm\s+test(\s|$)/, (c) => c.replace(/^pnpm test/, "rtk vitest run")],
  [/^npm\s+test(\s|$)/, (c) => c.replace(/^npm test/, "rtk npm test")],
  [/^npm\s+run\s+/, (c) => c.replace(/^npm run /, "rtk npm ")],
  [/^(npx\s+)?eslint(\s|$)/, (c) => c.replace(/^(npx )?eslint/, "rtk lint")],

  // --- Containers ---
  [/^docker\s+(ps|images|logs|run|build|exec)(\s|$)/, (c) => c.replace(/^docker /, "rtk docker ")],
  [/^kubectl\s+(get|logs|describe|apply)(\s|$)/, (c) => c.replace(/^kubectl /, "rtk kubectl ")],

  // --- Python ---
  [/^pytest(\s|$)/, (c) => c.replace(/^pytest/, "rtk pytest")],
  [/^python\s+-m\s+pytest(\s|$)/, (c) => c.replace(/^python -m pytest/, "rtk pytest")],
  [/^ruff\s+(check|format)(\s|$)/, (c) => c.replace(/^ruff /, "rtk ruff ")],
]

function rewrite(command) {
  if (typeof command !== "string") return null

  // Already using rtk
  if (/^(.*\/)?rtk\s/.test(command)) return null

  // Skip heredocs
  if (command.indexOf("<<") !== -1) return null

  // Strip leading env-var assignments for matching, preserve for output
  const envMatch = command.match(ENV_PREFIX_RE)
  const envPrefix = envMatch ? envMatch[0] : ""
  const body = envPrefix ? command.slice(envPrefix.length) : command

  for (const [pattern, rewriter] of RULES) {
    if (pattern.test(body)) {
      return envPrefix + rewriter(body)
    }
  }

  return null
}

let rtkAvailable = false

export default async ({ $, client }) => {
  try {
    await $`which rtk`.quiet()
    rtkAvailable = true
  } catch {
    // rtk not available
  }

  return {
    "tool.execute.before": async (input, output) => {
      if (!rtkAvailable) return

      const tool = String(input?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const args = output?.args
      if (!args || typeof args !== "object") return

      const cmd = args.command
      if (typeof cmd !== "string") return

      const rewritten = rewrite(cmd)
      if (rewritten) {
        args.command = rewritten
      }
    },
  }
}
