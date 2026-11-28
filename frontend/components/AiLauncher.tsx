import PandaIcon from "./PandaIcon";

// The AI assistant's launcher: the panda at the article
// header's top right, on every page the shell frames —
// an article's own header, and the home page's, which
// carries the site's name. It is the assistant's entrance
// at every width; the narrow screen's bottom bar holds
// another, for the reader whose header has scrolled
// away.
//
// The button is markup and nothing more: it carries no
// working of its own. The article it stands in is
// swapped for the next page's at every in-app navigation
// (see the link interceptor's swap), and a control
// swapped in with the article is inert — the page's
// first copy is the only one a framework ever wires up.
// So the working lives in the frame, which is never
// swapped: the assistant itself hears clicks on this
// button's class and toggles (see AiAssistant), as the
// interceptor hears the article's links, and it keeps
// the button's pressed state in step with its own by
// writing the attribute onto whichever copy stands.

export default function AiLauncher() {
  return (
    <button
      type="button"
      className="ai-launcher"
      aria-label="AI"
      aria-pressed="false"
    >
      <PandaIcon />
    </button>
  );
}
