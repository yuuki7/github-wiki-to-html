import { defineHastPlugin } from "satteri";

// Wraps every table in a container that scrolls sideways.
//
// A table wider than the article column cannot be made to
// fit: with automatic table layout its width is set by its
// contents. The choices are to let it stretch the page, to
// force it narrower and break the cell text wherever the
// width runs out, or to restyle the table element itself
// so it can scroll, which costs the table its meaning for
// assistive technology. Wrapping is the remaining option:
// the table stays exactly as it is, and the container,
// whose only job is scrolling, takes the overflow. The
// container is focusable so the table can also be scrolled
// with a keyboard.
export default defineHastPlugin({
  name: "table-wrap",
  element: {
    filter: ["table"],
    visit(node, ctx) {
      ctx.wrapNode(node, {
        type: "element",
        tagName: "div",
        properties: { className: ["table-scroll"], tabIndex: 0 },
        children: [],
      });
    },
  },
});
