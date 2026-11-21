// Render ```mermaid blocks. Mermaid loads only on pages that have a diagram.
(() => {
  const blocks = document.querySelectorAll("code.language-mermaid");
  if (blocks.length === 0) return;

  const html = document.documentElement.classList;
  const dark = ["coal", "navy", "ayu"].some((theme) => html.contains(theme));

  import("https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs").then(
    ({ default: mermaid }) => {
      for (const code of blocks) {
        const diagram = document.createElement("div");
        diagram.className = "mermaid";
        diagram.textContent = code.textContent;
        code.parentElement.replaceWith(diagram);
      }
      mermaid.initialize({ startOnLoad: false, theme: dark ? "dark" : "default" });
      mermaid.run();
    },
  );
})();
