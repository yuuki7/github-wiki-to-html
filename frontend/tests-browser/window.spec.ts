import { expect, test, type Locator, type Page } from "@playwright/test";

// The floating AI window's behaviour in a real browser.
// The arithmetic is pinned by the unit tests in
// frontend/tests/window-arrangement.test.ts; what is
// pinned here is the behaviour those tests cannot see:
// a window dragged by hand, a screen dragged through
// the crossing of its kinds, a window that must never
// be stranded where no control can reach it.

const articlePath = "/LilyPond-sheet-music";

interface Box {
  x: number;
  y: number;
  width: number;
  height: number;
}

const boxOf = async (window_: Locator): Promise<Box> => {
  const box = await window_.boundingBox();
  if (box === null) throw new Error("the window has no box");
  return box;
};

const openWindow = async (page: Page): Promise<Locator> => {
  await page.goto(articlePath);
  await page.click(".ai-launcher");
  const window_ = page.locator(".ai-assistant__window");
  await window_.waitFor({ state: "visible" });
  await page.waitForTimeout(400);
  return window_;
};

// Drag the window by an empty part of it — the middle
// of the conversation's ground — to the place given.
const dragWindowTo = async (page: Page, window_: Locator, left: number, top: number) => {
  const box = await boxOf(window_);
  await page.mouse.move(box.x + box.width / 2, box.y + box.height * 0.35);
  await page.mouse.down();
  await page.mouse.move(
    left + box.width / 2,
    top + box.height * 0.35,
    { steps: 12 },
  );
  await page.mouse.up();
  await page.waitForTimeout(300);
};

const near = (a: number, b: number, by = 3) => Math.abs(a - b) <= by;

test("an untouched window follows the corner as the browser widens through the crossing", async ({ page }) => {
  await page.setViewportSize({ width: 800, height: 900 });
  const window_ = await openWindow(page);
  const born = await boxOf(window_);
  expect(near(born.x + born.width, 800 - 6)).toBe(true);
  expect(near(born.y + born.height, 900 - 6)).toBe(true);

  // Through the crossing, step by step: the corner of
  // the screen it ends on, at the size it was born with.
  for (const width of [900, 961, 1100, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    await page.waitForTimeout(300);
    const box = await boxOf(window_);
    // The corner's margin is the kind's: a slighter one
    // while the screen is still narrow.
    const margin = width <= 960 ? 6 : 24;
    expect(near(box.width, born.width)).toBe(true);
    expect(near(box.height, born.height)).toBe(true);
    expect(near(box.x + box.width, width - margin)).toBe(true);
    expect(near(box.y + box.height, 900 - margin)).toBe(true);
  }

  // And back: the narrow corner again, exactly.
  await page.setViewportSize({ width: 800, height: 900 });
  await page.waitForTimeout(300);
  const back = await boxOf(window_);
  expect(near(back.x, born.x)).toBe(true);
  expect(near(back.y, born.y)).toBe(true);
  expect(near(back.width, born.width)).toBe(true);
  expect(near(back.height, born.height)).toBe(true);
});

test("a window dragged to the middle does not jump at the crossing, in either direction", async ({ page }) => {
  await page.setViewportSize({ width: 800, height: 900 });
  const window_ = await openWindow(page);
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.waitForTimeout(300);
  await dragWindowTo(page, window_, 400, 150);
  const dragged = await boxOf(window_);
  expect(near(dragged.x, 400)).toBe(true);
  expect(near(dragged.y, 150)).toBe(true);

  // Narrowing: the window is fitted where it stands —
  // its left edge drawn back only as far as the screen
  // forces — and not thrown to the narrow corner.
  await page.setViewportSize({ width: 800, height: 900 });
  await page.waitForTimeout(300);
  const narrowed = await boxOf(window_);
  expect(near(narrowed.x, 800 - dragged.width)).toBe(true);
  expect(near(narrowed.y, dragged.y)).toBe(true);
  expect(near(narrowed.width, dragged.width)).toBe(true);
  expect(near(narrowed.height, dragged.height)).toBe(true);

  // Widening back: the dragged place, exactly.
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.waitForTimeout(300);
  const back = await boxOf(window_);
  expect(near(back.x, dragged.x)).toBe(true);
  expect(near(back.y, dragged.y)).toBe(true);
  expect(near(back.width, dragged.width)).toBe(true);
  expect(near(back.height, dragged.height)).toBe(true);
});

test("a window dragged on a narrow screen is not snapped to the corner when the screen widens", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const window_ = await openWindow(page);
  await dragWindowTo(page, window_, 40, 80);
  const dragged = await boxOf(window_);
  expect(near(dragged.x, 40)).toBe(true);
  expect(near(dragged.y, 80)).toBe(true);

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.waitForTimeout(300);
  const widened = await boxOf(window_);
  expect(near(widened.x, dragged.x)).toBe(true);
  expect(near(widened.y, dragged.y)).toBe(true);
  expect(near(widened.width, dragged.width)).toBe(true);
  expect(near(widened.height, dragged.height)).toBe(true);

  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(300);
  const back = await boxOf(window_);
  expect(near(back.x, dragged.x)).toBe(true);
  expect(near(back.y, dragged.y)).toBe(true);
});

test("the default size keeps to a share of the screen, on screens only a little narrow or a little short", async ({ page }) => {
  // Narrow, and not tall: the ratio alone would cover
  // nearly the whole height.
  await page.setViewportSize({ width: 950, height: 700 });
  let window_ = await openWindow(page);
  let box = await boxOf(window_);
  expect(near(box.width, 378)).toBe(true);
  expect(near(box.height, 504)).toBe(true);
  expect(box.width <= 950 * 0.73).toBe(true);
  expect(box.height <= 700 * 0.73).toBe(true);

  await page.setViewportSize({ width: 800, height: 900 });
  await page.waitForTimeout(300);
  box = await boxOf(window_);
  // The size was taken at the first screen: it does not
  // grow into the second screen's default.
  expect(near(box.width, 378)).toBe(true);
  expect(near(box.height, 504)).toBe(true);

  // Wide but short, floated from the dock.
  const page2 = await page.context().newPage();
  await page2.setViewportSize({ width: 1440, height: 500 });
  await page2.goto(articlePath);
  await page2.click(".ai-launcher");
  await page2.waitForSelector(".ai-assistant__panel", { state: "visible" });
  await page2.click('.ai-assistant__panel button[aria-label="Float"]');
  window_ = page2.locator(".ai-assistant__window");
  await window_.waitFor({ state: "visible" });
  await page2.waitForTimeout(400);
  box = await boxOf(window_);
  expect(near(box.width, 270)).toBe(true);
  expect(near(box.height, 360)).toBe(true);
  expect(box.height <= 500 * 0.73).toBe(true);
});

test("the window is never stranded outside the screen, over a sweep of sizes", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const window_ = await openWindow(page);
  await dragWindowTo(page, window_, 50, 100);
  for (const [width, height] of [
    [1440, 900],
    [500, 700],
    [961, 600],
    [390, 844],
    [1200, 500],
    [800, 900],
  ] as const) {
    await page.setViewportSize({ width, height });
    await page.waitForTimeout(300);
    const box = await boxOf(window_);
    expect(box.x >= -1).toBe(true);
    expect(box.y >= -1).toBe(true);
    expect(box.x + box.width <= width + 1).toBe(true);
    expect(box.y + box.height <= height + 1).toBe(true);
  }
});

test("minimising and reopening keeps the dragged place", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const window_ = await openWindow(page);
  await dragWindowTo(page, window_, 40, 80);
  const dragged = await boxOf(window_);
  await page.click('.ai-assistant__window button[aria-label="Minimize"]');
  await window_.waitFor({ state: "hidden" });
  await page.click(".ai-launcher");
  await window_.waitFor({ state: "visible" });
  await page.waitForTimeout(400);
  const reopened = await boxOf(window_);
  expect(near(reopened.x, dragged.x)).toBe(true);
  expect(near(reopened.y, dragged.y)).toBe(true);
  expect(near(reopened.width, dragged.width)).toBe(true);
  expect(near(reopened.height, dragged.height)).toBe(true);
});
