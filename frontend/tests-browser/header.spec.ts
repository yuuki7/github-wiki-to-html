import { expect, test } from "@playwright/test";

// The article header's two buttons, in the built site
// (frontend/out, served by the config's webServer).
// Which build stands there is the run's business: this
// spec runs after build:site, like window.spec.ts.
//
// The launcher's place differs by the page: on an
// article page it stands at the date row's right end;
// on the home page it stays at the title's right end.
// The table of contents' toggle stands at the title's
// head, its icon small, and centred on the title's
// text.

const articlePath = "/Wikinder.html";

test("the launcher stands at the date row's right end on an article page", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1200, height: 900 });
  await page.goto(articlePath);
  const launcher = page.locator(".ai-launcher");
  const meta = page.locator(".article__meta").first();
  const header = page.locator(".article__header");
  const launcherBox = await launcher.boundingBox();
  const metaBox = await meta.boundingBox();
  const headerBox = await header.boundingBox();
  if (launcherBox === null || metaBox === null || headerBox === null) {
    throw new Error("the header's parts have no boxes");
  }
  // Centred on the date row, at the header's right edge.
  const launcherCentre = launcherBox.y + launcherBox.height / 2;
  const metaCentre = metaBox.y + metaBox.height / 2;
  expect(Math.abs(launcherCentre - metaCentre)).toBeLessThanOrEqual(3);
  expect(
    Math.abs(
      launcherBox.x + launcherBox.width - (headerBox.x + headerBox.width),
    ),
  ).toBeLessThanOrEqual(2);
});

test("the launcher stays at the title's right end on the home page", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1200, height: 900 });
  await page.goto("/");
  const launcher = page.locator(".ai-launcher");
  const header = page.locator(".article__header");
  const launcherBox = await launcher.boundingBox();
  const headerBox = await header.boundingBox();
  if (launcherBox === null || headerBox === null) {
    throw new Error("the header's parts have no boxes");
  }
  expect(Math.abs(launcherBox.y - headerBox.y)).toBeLessThanOrEqual(2);
  expect(
    Math.abs(
      launcherBox.x + launcherBox.width - (headerBox.x + headerBox.width),
    ),
  ).toBeLessThanOrEqual(2);
});

test("the contents icon is 0.6em, centred on the title's text", async ({
  page,
}) => {
  await page.setViewportSize({ width: 500, height: 900 });
  await page.goto(articlePath);
  const icon = page.locator(".toc-toggle__icon").first();
  await icon.waitFor({ state: "visible" });
  const measured = await page.evaluate(() => {
    const title = document.querySelector(".article__title");
    const iconElement = document.querySelector(".toc-toggle__icon");
    if (title === null || iconElement === null) {
      throw new Error("the title or the icon is gone");
    }
    const textNode = [...title.childNodes].find(
      (node) => node.nodeType === 3 && (node.textContent ?? "").trim() !== "",
    );
    if (textNode === undefined) throw new Error("the title has no text");
    const range = document.createRange();
    range.selectNodeContents(textNode);
    const textRect = range.getBoundingClientRect();
    const iconRect = iconElement.getBoundingClientRect();
    return {
      iconWidth: iconRect.width,
      fontSize: Number.parseFloat(getComputedStyle(title).fontSize),
      iconCentre: iconRect.top + iconRect.height / 2,
      textCentre: textRect.top + textRect.height / 2,
    };
  });
  expect(
    Math.abs(measured.iconWidth / measured.fontSize - 0.6),
  ).toBeLessThanOrEqual(0.02);
  expect(
    Math.abs(measured.iconCentre - measured.textCentre),
  ).toBeLessThanOrEqual(4);
});
