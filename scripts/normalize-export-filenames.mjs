// Gives exported page files the names a static host looks up.
//
// A static host resolves a request by percent-decoding its
// path once and matching a file, so a page's file must carry
// the decoded form of its URL — the slug itself. Next.js
// instead names the file after the route path it built,
// which escapes the path delimiters in a slug. A slug
// containing "?" is exported as "A%3FB.html", a name no
// request ever decodes to, and the page cannot be served.
// The md/ tree records the site's slugs; for each slug whose
// exported name differs from the slug, this pass renames the
// page's .html and .txt files to the slug. A rename that
// would land on a file this pass does not itself move fails
// the build instead of overwriting it.

import fs from "node:fs";
import path from "node:path";

const mdDir = "md";
const outDir = path.join("frontend", "out");

// The escaping Next.js applies to a dynamic segment when it
// builds a static path (escapePathDelimiters with
// escapeEncoded): the delimiters "/", "#", "?" and "\", plus
// a literal percent sequence that already spells one of them.
const escapeSegment = (segment) =>
  segment.replace(/[/\\#?]|\%(?:2f|23|3f|5c)/gi, (char) =>
    encodeURIComponent(char),
  );

// Every slug the site serves, from the converted Markdown.
const slugs = new Set();
for (const lang of fs.readdirSync(mdDir)) {
  const dir = path.join(mdDir, lang);
  if (!fs.statSync(dir).isDirectory()) continue;
  for (const name of fs.readdirSync(dir)) {
    if (name.endsWith(".md")) slugs.add(name.slice(0, -".md".length));
  }
}

// Escaped name -> slug, for the slugs the escaping changes.
const renames = new Map();
for (const slug of slugs) {
  const escaped = escapeSegment(slug);
  if (escaped !== slug) renames.set(escaped, slug);
}

// The page files under those names. _next and assets are not
// pages; their file names are not slugs.
const moves = [];
const walk = (dir) => {
  for (const name of fs.readdirSync(dir).sort()) {
    const full = path.join(dir, name);
    if (fs.statSync(full).isDirectory()) {
      if (name !== "_next" && name !== "assets") walk(full);
    } else if (name.endsWith(".html") || name.endsWith(".txt")) {
      const ext = name.endsWith(".html") ? ".html" : ".txt";
      const slug = renames.get(name.slice(0, -ext.length));
      if (slug) moves.push({ from: full, to: path.join(dir, slug + ext) });
    }
  }
};
walk(outDir);

const sources = new Set(moves.map((move) => move.from));
for (const move of moves) {
  if (fs.existsSync(move.to) && !sources.has(move.to)) {
    throw new Error(`${move.to}: a file this pass does not rename is in the way`);
  }
}

// Rename in two phases so that a target name still occupied
// by another move's source is vacated before anything lands
// on it.
for (const move of moves) {
  move.temp = `${move.from}.renaming`;
  fs.renameSync(move.from, move.temp);
}
for (const move of moves) {
  fs.renameSync(move.temp, move.to);
}
