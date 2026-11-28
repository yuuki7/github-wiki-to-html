import assert from "node:assert/strict";
import test from "node:test";
import {
  cornerPlace,
  defaultSize,
  dragWindow,
  emptyArrangement,
  fitRect,
  resizeWindow,
  standingRect,
  takeSize,
  type WindowArrangement,
} from "../lib/window-arrangement.ts";

test("defaultSize keeps the 3:4 ratio, the width the anchor", () => {
  assert.deepEqual(defaultSize({ width: 1440, height: 900 }, "wide"), {
    width: 384,
    height: 512,
  });
  // A bigger wide screen does not make a bigger window.
  assert.deepEqual(defaultSize({ width: 2560, height: 1440 }, "wide"), {
    width: 384,
    height: 512,
  });
  // A narrow screen: the width is 72% of the screen, the
  // height follows it by the ratio.
  assert.deepEqual(defaultSize({ width: 390, height: 844 }, "narrow"), {
    width: 281,
    height: 375,
  });
  // A tall thin browser window does not make a tall thin
  // window: the ratio holds.
  assert.deepEqual(defaultSize({ width: 500, height: 1200 }, "narrow"), {
    width: 360,
    height: 480,
  });
  assert.deepEqual(defaultSize({ width: 320, height: 568 }, "narrow"), {
    width: 230,
    height: 307,
  });
});

test("defaultSize keeps to a share of the screen in each direction", () => {
  // A screen only a little narrow: the ratio alone
  // would give a window covering nearly the whole
  // height. The height's share binds, and the width
  // follows it back.
  assert.deepEqual(defaultSize({ width: 950, height: 700 }, "narrow"), {
    width: 378,
    height: 504,
  });
  assert.deepEqual(defaultSize({ width: 800, height: 900 }, "narrow"), {
    width: 486,
    height: 648,
  });
  // A wide but short screen: the same bound.
  assert.deepEqual(defaultSize({ width: 1440, height: 500 }, "wide"), {
    width: 270,
    height: 360,
  });
});

test("defaultSize never passes its shares, over a sweep of screens", () => {
  for (const kind of ["wide", "narrow"] as const) {
    // A wide screen is wide: its widths start past the
    // breakpoint. A narrow screen's start at a phone's.
    const firstWidth = kind === "wide" ? 961 : 300;
    for (let width = firstWidth; width <= 2600; width += 137) {
      for (let height = 400; height <= 1600; height += 149) {
        const size = defaultSize({ width, height }, kind);
        assert.ok(
          size.width <= width * 0.73,
          `${kind} ${width}x${height}: width ${size.width}`,
        );
        assert.ok(
          size.height <= height * 0.73,
          `${kind} ${width}x${height}: height ${size.height}`,
        );
        assert.ok(size.width > 0 && size.height > 0);
        // The ratio, within the rounding of the anchors.
        assert.ok(
          Math.abs(size.width / size.height - 0.75) < 0.02,
          `${kind} ${width}x${height}: ratio ${size.width}/${size.height}`,
        );
      }
    }
  }
});

test("cornerPlace holds the window at the screen's corner, at its own size", () => {
  assert.deepEqual(
    cornerPlace(
      { width: 1440, height: 900 },
      { width: 281, height: 375 },
      false,
    ),
    { left: 1135, top: 501 },
  );
  assert.deepEqual(
    cornerPlace(
      { width: 1440, height: 900 },
      { width: 281, height: 375 },
      true,
    ),
    { left: 24, top: 501 },
  );
  assert.deepEqual(
    cornerPlace(
      { width: 390, height: 844 },
      { width: 281, height: 375 },
      false,
    ),
    { left: 85, top: 445 },
  );
});

test("the corner's margin is the same on either kind of screen", () => {
  // The gap between the window and the screen's right
  // and bottom edges, read through standingRect on an
  // untouched arrangement, does not change at the
  // crossing.
  const taken = takeSize(
    emptyArrangement,
    { width: 800, height: 900 },
    "narrow",
  );
  for (const [screen, kind] of [
    [{ width: 800, height: 900 }, "narrow"],
    [{ width: 959, height: 900 }, "narrow"],
    [{ width: 961, height: 900 }, "wide"],
    [{ width: 1440, height: 900 }, "wide"],
  ] as const) {
    const rect = standingRect(taken, screen, kind, false);
    assert.equal(screen.width - (rect.left + rect.width), 24);
    assert.equal(screen.height - (rect.top + rect.height), 24);
  }
});

test("takeSize writes the size once, from the screen it stands on", () => {
  const taken = takeSize(
    emptyArrangement,
    { width: 800, height: 900 },
    "narrow",
  );
  assert.deepEqual(taken.size, { width: 486, height: 648 });
  // Taken is taken: no later screen, of either kind,
  // writes it again.
  assert.equal(takeSize(taken, { width: 1440, height: 900 }, "wide"), taken);
  assert.equal(takeSize(taken, { width: 500, height: 700 }, "narrow"), taken);
});

test("a size taken on one kind of screen is the size on the other", () => {
  const taken = takeSize(
    emptyArrangement,
    { width: 800, height: 900 },
    "narrow",
  );
  const onWide = standingRect(
    taken,
    { width: 1440, height: 900 },
    "wide",
    false,
  );
  assert.equal(onWide.width, 486);
  assert.equal(onWide.height, 648);
  const onNarrow = standingRect(
    taken,
    { width: 390, height: 844 },
    "narrow",
    false,
  );
  // Fitted to the smaller screen for standing, but the
  // arrangement's size is untouched by the reading.
  assert.equal(onNarrow.width, 390);
  assert.deepEqual(taken.size, { width: 486, height: 648 });
});

test("an unwritten place follows the corner as the screen widens, through the crossing", () => {
  const taken = takeSize(
    emptyArrangement,
    { width: 800, height: 900 },
    "narrow",
  );
  assert.deepEqual(
    standingRect(taken, { width: 800, height: 900 }, "narrow", false),
    {
      left: 290,
      top: 228,
      width: 486,
      height: 648,
    },
  );
  // Still narrow, wider: the corner of the screen as it
  // stands, at the same size.
  assert.deepEqual(
    standingRect(taken, { width: 900, height: 900 }, "narrow", false),
    {
      left: 390,
      top: 228,
      width: 486,
      height: 648,
    },
  );
  // The crossing is passed through, not landed on: at
  // the wide screen the window ends on, the place is
  // that screen's corner — not the corner of the screen
  // at the crossing's first moment.
  assert.deepEqual(
    standingRect(taken, { width: 961, height: 900 }, "wide", false),
    {
      left: 451,
      top: 228,
      width: 486,
      height: 648,
    },
  );
  assert.deepEqual(
    standingRect(taken, { width: 1440, height: 900 }, "wide", false),
    {
      left: 930,
      top: 228,
      width: 486,
      height: 648,
    },
  );
  // And back: the narrow corner again, the size still
  // the size that was taken.
  assert.deepEqual(
    standingRect(taken, { width: 800, height: 900 }, "narrow", false),
    {
      left: 290,
      top: 228,
      width: 486,
      height: 648,
    },
  );
});

test("a dragged place does not move at the crossing, in either direction", () => {
  // Dragged to the middle of a narrow screen.
  const onNarrow = dragWindow(
    takeSize(emptyArrangement, { width: 390, height: 844 }, "narrow"),
    { left: 50, top: 100 },
  );
  // Widening does not throw it to the wide corner: it
  // stands where the reader put it.
  assert.deepEqual(
    standingRect(onNarrow, { width: 1440, height: 900 }, "wide", false),
    {
      left: 50,
      top: 100,
      width: 281,
      height: 375,
    },
  );
  // Dragged to the middle of a wide screen.
  const onWide = dragWindow(
    takeSize(emptyArrangement, { width: 1440, height: 900 }, "wide"),
    { left: 400, top: 200 },
  );
  // Narrowing does not throw it to the narrow corner
  // either.
  assert.deepEqual(
    standingRect(onWide, { width: 800, height: 900 }, "narrow", false),
    {
      left: 400,
      top: 200,
      width: 384,
      height: 512,
    },
  );
});

test("a dragged place survives the round trip exactly, in both directions", () => {
  const dragged = dragWindow(
    takeSize(emptyArrangement, { width: 1440, height: 900 }, "wide"),
    { left: 100, top: 50 },
  );
  // Out to the narrow screen and back: the place the
  // reader made, exactly.
  standingRect(dragged, { width: 390, height: 844 }, "narrow", false);
  assert.deepEqual(
    standingRect(dragged, { width: 1440, height: 900 }, "wide", false),
    {
      left: 100,
      top: 50,
      width: 384,
      height: 512,
    },
  );
  const draggedNarrow = dragWindow(
    takeSize(emptyArrangement, { width: 390, height: 844 }, "narrow"),
    { left: 50, top: 100 },
  );
  standingRect(draggedNarrow, { width: 1440, height: 900 }, "wide", false);
  assert.deepEqual(
    standingRect(draggedNarrow, { width: 390, height: 844 }, "narrow", false),
    {
      left: 50,
      top: 100,
      width: 281,
      height: 375,
    },
  );
});

test("a dragged place past a smaller screen's edge is fitted for standing, and kept", () => {
  const dragged = dragWindow(
    takeSize(emptyArrangement, { width: 1440, height: 900 }, "wide"),
    { left: 1000, top: 388 },
  );
  // On the narrow screen the window is drawn back
  // inside — for standing.
  assert.deepEqual(
    standingRect(dragged, { width: 390, height: 844 }, "narrow", false),
    {
      left: 6,
      top: 332,
      width: 384,
      height: 512,
    },
  );
  // The arrangement keeps the reader's place exactly,
  // and the wide screen gives it back untouched.
  assert.deepEqual(dragged.place, { left: 1000, top: 388 });
  assert.deepEqual(
    standingRect(dragged, { width: 1440, height: 900 }, "wide", false),
    {
      left: 1000,
      top: 388,
      width: 384,
      height: 512,
    },
  );
});

test("a browser resize within a kind leaves a dragged place alone", () => {
  const dragged = dragWindow(
    takeSize(emptyArrangement, { width: 1440, height: 900 }, "wide"),
    { left: 100, top: 50 },
  );
  assert.deepEqual(
    standingRect(dragged, { width: 1200, height: 800 }, "wide", false),
    {
      left: 100,
      top: 50,
      width: 384,
      height: 512,
    },
  );
});

test("resizeWindow writes the one size and the place it ends at", () => {
  const taken = takeSize(
    emptyArrangement,
    { width: 1440, height: 900 },
    "wide",
  );
  const resized = resizeWindow(taken, {
    left: 200,
    top: 150,
    width: 400,
    height: 300,
  });
  assert.deepEqual(
    standingRect(resized, { width: 1440, height: 900 }, "wide", false),
    {
      left: 200,
      top: 150,
      width: 400,
      height: 300,
    },
  );
  // The size is the one size, and the place the one
  // place: the narrow screen stands at them too.
  assert.deepEqual(
    standingRect(resized, { width: 800, height: 900 }, "narrow", false),
    {
      left: 200,
      top: 150,
      width: 400,
      height: 300,
    },
  );
});

test("fitRect cuts an oversized window down and draws a stray one back inside", () => {
  assert.deepEqual(
    fitRect(
      { left: -50, top: 950, width: 500, height: 400 },
      { width: 1000, height: 900 },
    ),
    { left: 0, top: 500, width: 500, height: 400 },
  );
  assert.deepEqual(
    fitRect(
      { left: 0, top: 0, width: 1200, height: 1000 },
      { width: 1000, height: 900 },
    ),
    { left: 0, top: 0, width: 1000, height: 900 },
  );
});

test("the writers never mutate the arrangement they are given", () => {
  const taken = takeSize(
    emptyArrangement,
    { width: 800, height: 900 },
    "narrow",
  );
  const snapshot: WindowArrangement = JSON.parse(JSON.stringify(taken));
  dragWindow(taken, { left: 1, top: 2 });
  resizeWindow(taken, { left: 1, top: 2, width: 3, height: 4 });
  standingRect(taken, { width: 390, height: 844 }, "narrow", false);
  standingRect(taken, { width: 1440, height: 900 }, "wide", false);
  assert.deepEqual(taken, snapshot);
  assert.deepEqual(emptyArrangement, { place: null, size: null });
});
