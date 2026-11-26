// The frame's floating layers and the order they were
// opened in. Two things can stand over the article at
// once on a narrow screen: the menu drawer and the AI
// window. A tap back on the article puts away one of
// them — the one opened most recently, as a reader
// expects of stacked layers — so the two dismissals
// (the menu's in MenuDismiss, the window's in
// AiAssistant) share this record of which was opened
// last. Each layer notes its own opening where that
// opening is seen: the menu from its <details>' toggle
// event, the window from its opening. The record lives
// in the frame's module state, like the AI engine and
// its history (see ai-client.ts): it is kept while the
// reader moves between pages, and a fresh page load
// starts it empty, as both layers start closed.

export type FloatingLayer = "menu" | "ai";

let mostRecent: FloatingLayer | null = null;

export function noteLayerOpened(layer: FloatingLayer): void {
  mostRecent = layer;
}

export function mostRecentLayer(): FloatingLayer | null {
  return mostRecent;
}
