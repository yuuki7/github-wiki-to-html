"use client";

import PandaIcon from "./PandaIcon";

// The AI assistant's launcher: the panda at the article
// header's top right, on every page the shell frames —
// an article's own header, and the home page's, which
// carries the site's name. It is the assistant's entrance
// at every width; the narrow screen's bottom bar holds
// another, for the reader whose header has scrolled
// away. The button owns nothing of the assistant's state:
// it asks the assistant to toggle itself with the event
// the bottom bar's AI button also uses, and the assistant
// keeps the button's pressed state in step with its own
// (see AiAssistant).

export default function AiLauncher() {
  const toggleAssistant = () => {
    window.dispatchEvent(new Event("ai-assistant:toggle"));
  };

  return (
    <button
      type="button"
      className="ai-launcher"
      aria-label="AI"
      aria-pressed="false"
      onClick={toggleAssistant}
    >
      <PandaIcon />
    </button>
  );
}
