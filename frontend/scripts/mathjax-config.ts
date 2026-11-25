// The MathJax configuration. This script must run before the
// MathJax startup script, so that window.MathJax is in place
// when MathJax loads.

// A math item, in the shape the code below builds: its start
// and end, each on a text node.
interface MathItem {
  start: { node: Text; delim: string; n: number };
  end: { node: Text; delim: string; n: number };
}

// The pieces of the MathJax document that the code-math
// action below works with: the math item class, the TeX
// input processor, and the document's list of math items.
interface MathDocument {
  options: {
    MathItem: new (math: string, jax: object, display: boolean) => MathItem;
  };
  inputJax: { tex: object };
  math: { push: (item: MathItem) => void };
}

// The configuration itself, as MathJax reads it from
// window.MathJax.
interface MathJaxConfig {
  startup: { typeset: boolean };
  loader: { load: string[] };
  tex: { inlineMath: [string, string][] };
  output: { fontExtensions: string[] };
  options: {
    renderActions: {
      findCodeMath: [number, (doc: MathDocument) => void, string, boolean];
    };
  };
}

interface Window {
  MathJax: MathJaxConfig;
}

window.MathJax = {
  startup: {
    // MathJax does not typeset on its own. On a full load its
    // typesetting races the framework's hydration of the same
    // article: when MathJax finishes first — the warm-cache
    // case, where its scripts and components come from the
    // cache — hydration finds the article rewritten under it,
    // throws it away, and the typeset mathematics goes with
    // it. So the shell typesets every page itself, once the
    // page is in place, as it already does for a page swapped
    // in by navigation.
    typeset: false,
  },

  loader: {
    load: ["input/tex", "output/chtml"],
  },

  tex: {
    // Authors write inline math as $...$, in addition to the
    // default \(...\).
    inlineMath: [
      ["\\(", "\\)"],
      ["$", "$"],
    ],
  },

  output: {
    // Use the Euler font.
    fontExtensions: ["mathjax-euler"],
  },

  options: {
    renderActions: {
      // The code form of GitHub's math syntax, $`...`$, reaches
      // the page as a <code> element between two "$" text nodes,
      // which the delimiter search cannot read as math. Turn
      // each one into a math item before that search runs, and
      // take the "$"s away so the search does not see them.
      findCodeMath: [
        9,
        (doc) => {
          for (const code of document.querySelectorAll("code")) {
            if (code.closest("pre")) continue;

            const before = code.previousSibling;
            const after = code.nextSibling;
            if (!(before instanceof Text)) continue;
            if (!(after instanceof Text)) continue;
            if (!before.textContent.endsWith("$")) continue;
            if (!after.textContent.startsWith("$")) continue;

            before.textContent = before.textContent.slice(0, -1);
            after.textContent = after.textContent.slice(1);

            const math = new doc.options.MathItem(
              code.textContent ?? "",
              doc.inputJax.tex,
              false,
            );
            const text = document.createTextNode("");
            const parent = code.parentNode;
            if (!parent) continue;
            parent.replaceChild(text, code);
            math.start = { node: text, delim: "", n: 0 };
            math.end = { node: text, delim: "", n: 0 };
            doc.math.push(math);
          }
        },
        "",
        false,
      ],
    },
  },
};
