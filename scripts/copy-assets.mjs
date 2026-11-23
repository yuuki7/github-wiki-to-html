// Copies the content's non-Markdown files into the built
// site's assets. Articles reference images by a path relative
// to their own file (see site/lib/markdown.ts, which rewrites the
// references to /assets/<name>); the files themselves live
// beside the articles, one copy per language. The copies of
// one name must be the same file — a name that means two
// different files in two languages fails the build here
// instead of serving whichever copy was found last.

import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const mdDir = "md";
const assetsDir = path.join("site", "out", "assets");

const byName = new Map();
const walk = (dir) => {
  for (const name of fs.readdirSync(dir).sort()) {
    const full = path.join(dir, name);
    if (fs.statSync(full).isDirectory()) {
      walk(full);
    } else if (!name.endsWith(".md")) {
      const bytes = fs.readFileSync(full);
      const hash = createHash("sha256").update(bytes).digest("hex");
      const seen = byName.get(name);
      if (seen && seen.hash !== hash) {
        throw new Error(
          `${name}: different files in ${seen.from} and ${full}`,
        );
      }
      byName.set(name, { hash, from: full, bytes });
    }
  }
};
walk(mdDir);

fs.mkdirSync(assetsDir, { recursive: true });
for (const [name, file] of byName) {
  fs.writeFileSync(path.join(assetsDir, name), file.bytes);
}
