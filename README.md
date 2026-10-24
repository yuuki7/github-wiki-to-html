# github-wiki-to-html

Converts GitHub Wiki Markdown files into HTML files.

## Workflow

```mermaid
graph TD
    A["GitHub Wiki Markdown files"] -->|"gollum-lib (Ruby)"| B["JSON data"]
    B -->|"Astro (JavaScript)"| C["HTML files"]
```

## Background

The GitHub Wiki backend is proprietary, and the Gollum project aims to provide a compatible implementation. This project uses `gollum-lib` to parse the Markdown files into JSON data, and Astro as a static site generator (SSG) to build the HTML files.
