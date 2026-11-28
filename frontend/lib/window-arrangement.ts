// The floating AI window's arrangement: where it
// stands, and how big it is. The arrangement is the
// reader's, and it is one arrangement: the window is
// one window on one screen, and the screen's changing
// size — even across the boundary between a wide screen
// and a narrow one — does not make it two. The kind of
// screen governs the page's layout (whether a dock can
// stand beside the article), not the window's place: a
// place kept separately for each kind throws the window
// at every crossing — to the corner, when the kind it
// crosses to has no place of the reader's — which is a
// jump, not a move.
//
// Two parts of the arrangement are defaults until the
// reader's hand writes them, and they differ. The size
// is taken once, when the window first stands, from the
// screen as it is at that moment (see takeSize): a size
// read afresh from the screen at every drawing would
// grow and shrink as the reader resizes the browser.
// The place, while the reader has not written it, is
// the screen's corner, read as the screen stands (see
// standingRect): the crossing of the kinds is not an
// instant in the reader's hand — the browser is dragged
// through it, widening as it goes — so a corner taken
// at the crossing's first moment would strand the
// window short of the corner of the screen it ends on.
// A written place, by contrast, is kept exactly, on
// either kind of screen: the window stands where the
// reader put it, and a round trip out and back restores
// it exactly.
//
// What the screen governs is only how the arrangement
// stands while it lasts (see fitRect): a window larger
// than the screen is cut down to it for standing, and
// one past an edge is drawn back inside, so the window
// is never nowhere. The fitting is a reading, never
// written back into the arrangement.

export interface ScreenSize {
  width: number;
  height: number;
}

export type ScreenKind = "wide" | "narrow";

export interface WindowSize {
  width: number;
  height: number;
}

export interface WindowPlace {
  left: number;
  top: number;
}

export interface WindowRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface WindowArrangement {
  place: WindowPlace | null;
  size: WindowSize | null;
}

export const emptyArrangement: WindowArrangement = {
  place: null,
  size: null,
};

// The window's margin from the screen's corner. It is
// one margin, on either kind of screen: a margin that
// changed at the crossing would move the window at the
// crossing — the window standing further from the
// corner on one kind than on the other — which is the
// crossing's own kind of jump.
const windowMargin = 24;

// The window's default size. It keeps one fixed ratio,
// three wide to four tall, on either kind of screen: a
// window whose height is a share of the screen's height
// and whose width is a share of its width takes the
// screen's own shape — tall and thin in a tall thin
// browser window — which is the screen's shape, not a
// window's. And it keeps to a share of the screen in
// each direction — about seventy-two hundredths — on
// either kind: a ratio alone does not bound it, and on
// a screen only a little narrow, or only a little
// short, a window sized by the ratio alone would cover
// nearly the whole screen and stop being a window over
// the page. So the width is the anchor — at most 384 on
// a wide screen, at most the width's share on a narrow
// one — the height follows it by the ratio, and where
// the height would pass the height's share, the height
// is the anchor instead and the width follows it back,
// the ratio kept either way.
export function defaultSize(screen: ScreenSize, kind: ScreenKind): WindowSize {
  const widest = kind === "narrow" ? Math.round(screen.width * 0.72) : 384;
  const tallest = Math.round(screen.height * 0.72);
  let width = Math.min(widest, screen.width - windowMargin * 2);
  let height = Math.round((width * 4) / 3);
  const maxHeight = Math.min(tallest, screen.height - windowMargin * 2);
  if (height > maxHeight) {
    height = maxHeight;
    width = Math.round((height * 3) / 4);
  }
  return { width, height };
}

// The default place: the screen's bottom right corner —
// the bottom left in a right-to-left language — a
// margin in from the edges, holding a window of the
// size given, whatever that size is.
export function cornerPlace(
  screen: ScreenSize,
  size: WindowSize,
  rtl: boolean,
): WindowPlace {
  return {
    left: rtl ? windowMargin : screen.width - size.width - windowMargin,
    top: screen.height - size.height - windowMargin,
  };
}

// Taking the size: the window writes its default size
// into the arrangement, once, when it first stands. A
// size already taken — by this, or by the reader's own
// resizing of the window — is left exactly as it is.
export function takeSize(
  arrangement: WindowArrangement,
  screen: ScreenSize,
  kind: ScreenKind,
): WindowArrangement {
  if (arrangement.size !== null) return arrangement;
  return { ...arrangement, size: defaultSize(screen, kind) };
}

// The reader drags the window: the one place is
// written.
export function dragWindow(
  arrangement: WindowArrangement,
  place: WindowPlace,
): WindowArrangement {
  return { ...arrangement, place };
}

// The reader resizes the window: the one size is
// written, and the place it ends at.
export function resizeWindow(
  arrangement: WindowArrangement,
  rect: WindowRect,
): WindowArrangement {
  return {
    place: { left: rect.left, top: rect.top },
    size: { width: rect.width, height: rect.height },
  };
}

// The window's place, fitted to the screen as it stands
// now, for standing: a window larger than the screen is
// cut down to it, and one past an edge is drawn back
// inside. A reading only — the arrangement it is read
// from is never changed by it.
export function fitRect(rect: WindowRect, screen: ScreenSize): WindowRect {
  const width = Math.min(rect.width, screen.width);
  const height = Math.min(rect.height, screen.height);
  return {
    left: Math.min(Math.max(rect.left, 0), screen.width - width),
    top: Math.min(Math.max(rect.top, 0), screen.height - height),
    width,
    height,
  };
}

// How the window stands on the screen as it is: the
// arrangement's size — the default of this screen until
// the size is taken — at the arrangement's place, or at
// this screen's corner while the place is the reader's
// to write, fitted to the screen for standing.
export function standingRect(
  arrangement: WindowArrangement,
  screen: ScreenSize,
  kind: ScreenKind,
  rtl: boolean,
): WindowRect {
  const size = arrangement.size ?? defaultSize(screen, kind);
  const place = arrangement.place ?? cornerPlace(screen, size, rtl);
  return fitRect({ ...place, ...size }, screen);
}
