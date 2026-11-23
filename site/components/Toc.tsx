import type { Heading } from "../lib/markdown";

// The article's table of contents, in its left sidebar: the
// headings the renderer collected, as links to their anchors.

export default function Toc({ headings }: { headings: Heading[] }) {
  // Depths 2 to 4, without the heading the renderer adds for the
  // footnotes section: the list is the article's own structure.
  const items = headings.filter(
    (h) => h.depth >= 2 && h.depth <= 4 && h.slug !== "footnote-label",
  );
  if (items.length === 0) return null;
  return (
    <nav className="toc">
      <ul>
        {items.map((h) => (
          <li key={h.slug} className={`toc__item toc__item--depth-${h.depth}`}>
            <a className="toc__link" href={`#${h.slug}`}>
              {h.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
