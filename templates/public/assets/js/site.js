"use strict";
// The copy button on code blocks. Copying needs the Clipboard
// API, so the button itself is made here, by script: without
// script there is no button, rather than a button that does
// nothing.
// The labels are emoji, so they do not depend on the page's
// language.
const copyLabel = "📋";
const copiedLabel = "✅";
for (const pre of document.querySelectorAll("pre.astro-code")) {
  // Wrap the block, so the button can sit at its corner
  // without scrolling away with the code.
  const wrapper = document.createElement("div");
  wrapper.className = "code-block";
  pre.replaceWith(wrapper);
  wrapper.append(pre);
  // The button itself, in the not-yet-copied state.
  const button = document.createElement("button");
  button.type = "button";
  button.className = "copy-button";
  button.textContent = copyLabel;
  wrapper.append(button);
  // A click copies the block's text. If the clipboard is
  // unavailable, nothing changes.
  let timer;
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(
        pre.querySelector("code")?.textContent ?? "",
      );
    } catch {
      return;
    }
    // Show the copied label for two seconds, then go back.
    button.textContent = copiedLabel;
    clearTimeout(timer);
    timer = setTimeout(() => {
      button.textContent = copyLabel;
    }, 2000);
  });
}
