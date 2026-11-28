"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  articleTextLimit,
  checkCache,
  dropPreviousModel,
  getEngine,
  historyLimit,
  loadHistory,
  modelId,
  saveHistory,
  setEngine,
  trimHistory,
  UnsupportedError,
  type Engine,
  type Message,
  type WebLLM,
} from "../lib/ai-client";
import { mostRecentLayer, noteLayerOpened } from "../lib/layers";
import type { AiStrings } from "../lib/types";
import PandaIcon from "./PandaIcon";

// The AI box: one question form, answered by a small
// language model that runs entirely in the reader's browser,
// through WebLLM. Nothing is sent to a server. The library
// and the model are loaded when the reader first submits the
// form. The form is rendered once the component has mounted:
// without script there is no form, rather than a form that
// does nothing.
//
// The box starts minimized: nothing of it stands on the
// page but its launcher, the panda at the article header's
// top right (see AiLauncher), and the section itself is
// empty. Opened on a wide screen, the box stands docked:
// the page gives it the right column, the left sidebar
// folds away, the article moves over, and the panel stands
// fixed at the screen's full height while the article
// scrolls past it, its conversation scrolling within
// itself. The divider at the panel's edge gives the reader
// the column's width. From the dock the box can be floated
// — the window it was before, dragged by any empty part,
// resized from any edge or corner — and docked back; and
// it can be made the whole
// screen, which on the home page is the way a reader who
// came only for the assistant uses it. On a narrow screen
// there is no dock to stand in the page: the box opens as
// the floating window, over the page, in the part of the
// screen above the bottom bar, and a box whose form is
// the dock stands there as the full screen instead —
// the form that fills a narrow screen, as the dock fills
// its column on a wide one. Minimizing, from any of the forms, keeps the
// floating window's place, so it opens again where it left
// off; the dock's width is kept likewise, in the reader's
// own storage.
//
// The box is part of the app's frame, not of the page: the
// frame stays mounted while the reader moves between pages,
// so the box's own state — the question being typed above
// all — is kept by the box itself staying in place. The
// engine and the conversation live in lib/ai-client.ts.

export default function AiAssistant({ strings }: { strings: AiStrings }) {
  // The messages on display, the status line's text (null
  // hides it), and whether the model is busy. The form exists
  // only after mounting: before that, the box is its heading,
  // exactly what a reader without script is served.
  const [mounted, setMounted] = useState(false);
  const [log, setLog] = useState<Message[]>([]);
  const [status, setStatus] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [draftText, setDraftText] = useState("");
  const busyRef = useRef(false);

  useEffect(() => {
    setMounted(true);
    setLog([...loadHistory()]);
  }, []);

  // The article's text, as the reader sees it, cut to the
  // limit the model can read (lib/ai-client.ts).
  const articleText = (): string =>
    (
      document.querySelector<HTMLElement>(".article__main")?.innerText ?? ""
    ).slice(0, articleTextLimit);

  // The system message: the article, and the one instruction
  // that matters, to answer in the article's own language.
  const systemMessage = (): Message => ({
    role: "system",
    content:
      "You are an assistant on a wiki article page. The article " +
      "is below. Summarize it when asked, and answer questions " +
      "about it. Always reply in the article's language.\n\n" +
      articleText(),
  });

  // Create the engine from an imported library. The loading
  // progress is reported only for an uncached model: a cached
  // model loads with no progress shown at all.
  const createEngine = async (found: {
    webllm: WebLLM;
    cached: boolean;
  }): Promise<Engine> =>
    found.webllm.CreateMLCEngine(modelId, {
      initProgressCallback: (report) => {
        if (!found.cached) {
          setStatus(
            `${liveStrings().loading} ${Math.round(report.progress * 100)}%`,
          );
        }
      },
    });

  // Ask the model, with the article and the conversation so
  // far, and stream the answer into a new log entry.
  const generate = async (activeEngine: Engine): Promise<void> => {
    setLog((previous) => [...previous, { role: "assistant", content: "" }]);
    let reply = "";
    const chunks = await activeEngine.chat.completions.create({
      messages: [systemMessage(), ...loadHistory()],
      stream: true,
    });
    for await (const chunk of chunks) {
      reply += chunk.choices[0]?.delta?.content ?? "";
      setLog((previous) => [
        ...previous.slice(0, -1),
        { role: "assistant", content: reply },
      ]);
    }
    const conversation = loadHistory();
    conversation.push({ role: "assistant", content: reply });
    trimHistory();
    // Keep what is on screen in step with what survives a reload.
    setLog((previous) => previous.slice(-historyLimit));
    saveHistory();
  };

  // The form's submit: the typed question is asked; an empty
  // input sends nothing. The first submit loads the model. A
  // failure shows the error text and leaves the form usable,
  // so the reader can try again.
  const onSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (busyRef.current) return;
    const question = draftText.trim();
    if (question === "") return;
    const previousLog = log;
    setDraftText("");
    setLog((previous) => [...previous, { role: "user", content: question }]);
    loadHistory().push({ role: "user", content: question });
    busyRef.current = true;
    setBusy(true);
    // A retry must not keep an earlier failure's message on screen.
    setStatus(null);
    try {
      let activeEngine = getEngine();
      if (!activeEngine) {
        if (!navigator.gpu)
          throw new UnsupportedError(liveStrings().unsupported);
        const found = await checkCache();
        if (!found) throw new Error(liveStrings().error);
        await dropPreviousModel(found.webllm);
        activeEngine = await createEngine(found);
        setEngine(activeEngine);
        setStatus(null);
      }
      await generate(activeEngine);
    } catch (error) {
      loadHistory().pop();
      saveHistory();
      // A failed stream may have already rendered its partial
      // assistant message. Restore the transcript to match the
      // history that was retained for the next request.
      setLog(previousLog);
      setStatus(
        error instanceof UnsupportedError
          ? liveStrings().unsupported
          : liveStrings().error,
      );
    } finally {
      busyRef.current = false;
      setBusy(false);
    }
  };

  // The box's texts, read from the section's own data
  // attributes at the moment of use. The frame is not
  // re-rendered when the reader moves — in-app navigation
  // updates the attributes in place, the language included —
  // so the texts current when the reader acts are the ones
  // in the document, not the ones this render was given. The
  // render's own strings are the fallback before the section
  // exists.
  const sectionRef = useRef<HTMLElement>(null);
  const liveStrings = (): AiStrings => {
    const data = sectionRef.current?.dataset;
    return {
      summarize: data?.summarize ?? strings.summarize,
      loading: data?.loading ?? strings.loading,
      send: data?.send ?? strings.send,
      unsupported: data?.unsupported ?? strings.unsupported,
      error: data?.error ?? strings.error,
      message: data?.message ?? strings.message,
    };
  };

  const logRef = useRef<HTMLDivElement>(null);

  // Enter sends; Shift+Enter makes a new line, and an Enter
  // that only confirms a conversion of the reader's input
  // method sends nothing.
  const onInputKeyDown = (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key !== "Enter" || event.shiftKey) return;
    if (event.nativeEvent.isComposing) return;
    event.preventDefault();
    if (!busyRef.current && draftText.trim() !== "") {
      event.currentTarget.form?.requestSubmit();
    }
  };

  // The box's placement: minimized away, docked in the
  // page's right column, floating where the reader has
  // put it, or filling the screen. The placement is the
  // box's own state, so it is kept like the rest of the
  // box's state while the reader moves between pages. The
  // rectangle is the floating window's, in viewport
  // coordinates. The box's element sits in the right
  // sidebar: minimized it is empty and the sidebar is left
  // blank, docked the stylesheet stands the sidebar itself
  // up as the panel, and floating the window leaves the
  // sidebar and floats over the page as before.
  interface WindowRect {
    left: number;
    top: number;
    width: number;
    height: number;
  }
  type Placement = "minimized" | "docked" | "floating" | "fullscreen";
  const [placement, setPlacement] = useState<Placement>("minimized");
  const [rect, setRect] = useState<WindowRect>({
    left: 0,
    top: 0,
    width: 0,
    height: 0,
  });
  const windowRef = useRef<HTMLDivElement>(null);

  // The conversation's end stays in view: the log scrolls
  // within the window, a new message — the reader's own
  // above all — is no use below the fold, and a window
  // opened on an earlier conversation starts at its end,
  // where the latest message is.
  useEffect(() => {
    const element = logRef.current;
    if (element) element.scrollTop = element.scrollHeight;
  }, [log, placement]);

  // The window's default place. On a wide screen: the
  // screen's bottom right corner — the bottom left in a
  // right-to-left language — a margin in from the edges,
  // at a size a conversation can start in, cut down to
  // fit a smaller screen. On a narrow screen the same
  // corner, with a slighter margin, in the part of the
  // screen above the bottom bar: the bar stays clear of
  // the window, and the window takes about seventy-two
  // hundredths of that part's width and height — large,
  // but plainly a window over the page, not the page
  // itself.
  // The narrow screen's bottom bar, measured where it
  // stands: the window's places on a narrow screen are
  // all in the part of the screen above it.
  const bottomBarHeight = (): number =>
    document.querySelector(".bottom-bar")?.getBoundingClientRect().height ?? 0;

  const homeRect = (): WindowRect => {
    if (window.matchMedia("(max-width: 60rem)").matches) {
      const margin = 6;
      const areaHeight = window.innerHeight - bottomBarHeight();
      const width = Math.round(window.innerWidth * 0.72);
      const height = Math.round(areaHeight * 0.72);
      const rtl = document.documentElement.dir === "rtl";
      return {
        left: rtl ? margin : window.innerWidth - width - margin,
        top: areaHeight - height - margin,
        width,
        height,
      };
    }
    const margin = 24;
    const width = Math.min(384, window.innerWidth - margin * 2);
    const height = Math.min(512, window.innerHeight - margin * 2);
    const rtl = document.documentElement.dir === "rtl";
    return {
      left: rtl ? margin : window.innerWidth - width - margin,
      top: window.innerHeight - height - margin,
      width,
      height,
    };
  };

  // Which screen the box is on, wide or narrow, kept as
  // the screen changes.
  const [narrowScreen, setNarrowScreen] = useState(false);
  useEffect(() => {
    const query = window.matchMedia("(max-width: 60rem)");
    const update = () => setNarrowScreen(query.matches);
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  });

  // The form the box stands in, as the page and the
  // stylesheet see it. The placement is the form the
  // reader chose; the dock among the forms is a wide
  // screen's, and on a narrow screen a docked box stands
  // as the full screen — the form that fills the screen
  // there, as the dock fills its column on a wide one.
  // The window and the full screen are both screens'
  // forms, and stand as chosen on either. Nothing is
  // changed by the screen's turning: the chosen form is
  // only read through it, and widening the screen again
  // stands the dock back up, untouched.
  const effectivePlacement: Placement =
    placement === "docked" && narrowScreen ? "fullscreen" : placement;

  // Opening the box: on a wide screen it docks, on a
  // narrow one it floats. The floating window opens where
  // it last was — its rectangle survives minimizing — so
  // only an opening on a freshly loaded page, no rectangle
  // yet, starts from the default place.
  const openAssistant = () => {
    if (narrowScreen) {
      if (rect.width === 0) setRect(homeRect());
      setPlacement("floating");
      noteLayerOpened("ai");
    } else {
      setPlacement("docked");
    }
  };

  // Minimizing keeps the window's place and size, and the
  // dock's width: the reader's arrangement is worth more
  // than the defaults, and the defaults are still there —
  // they are where a freshly loaded page puts the box.
  const minimizeAssistant = () => {
    setPlacement("minimized");
  };

  // The dock and the floating window are two forms of the
  // one box, and the heading carries the reader between
  // them; the full screen is the dock widened to the
  // whole page, and its control steps back to the dock.
  const floatAssistant = () => {
    if (rect.width === 0) setRect(homeRect());
    setPlacement("floating");
    noteLayerOpened("ai");
  };
  const dockAssistant = () => {
    if (narrowScreen) return;
    setPlacement("docked");
  };
  const fullScreenAssistant = () => {
    setPlacement("fullscreen");
  };

  // The form the box stands in, told to the page: the
  // stylesheet lays the page out around a standing panel
  // from the body's classes, and the panda buttons — the
  // launcher in the article header, a fresh element on
  // every page, and the bottom bar's button — take their
  // pressed state from here, on a navigation as on a
  // change of the form itself.
  useEffect(() => {
    const sync = () => {
      document.body.classList.toggle(
        "ai-open",
        effectivePlacement === "docked" || effectivePlacement === "fullscreen",
      );
      document.body.classList.toggle(
        "ai-fullscreen",
        effectivePlacement === "fullscreen",
      );
      document
        .querySelectorAll(".ai-launcher, .bottom-bar__button--ai")
        .forEach((button) =>
          button.setAttribute(
            "aria-pressed",
            effectivePlacement === "minimized" ? "false" : "true",
          ),
        );
    };
    sync();
    // Leaving the dock on a wide screen takes the menu's
    // drawer with it: the drawer's control — the article
    // title's button — stands only while the panel does,
    // and a drawer left standing would keep only the
    // article's own dismissals. On a narrow screen the
    // menu is the bottom bar's business, not the dock's,
    // and it is left alone.
    if (
      effectivePlacement !== "docked" &&
      effectivePlacement !== "fullscreen" &&
      !window.matchMedia("(max-width: 60rem)").matches
    ) {
      const details = document.querySelector<HTMLDetailsElement>(
        ".left-sidebar > details",
      );
      if (details) details.open = false;
    }
    window.addEventListener("frame:navigated", sync);
    return () => window.removeEventListener("frame:navigated", sync);
  }, [effectivePlacement]);

  // The dock's width, in pixels, once the reader has
  // dragged its divider; until then the stylesheet's own
  // width — the whole of the screen the article's measure
  // leaves — stands. The width is the reader's, so it is
  // kept in their storage and restored on a later visit,
  // and it is written to the body's style, where the
  // stylesheet's grid takes it from.
  const [aiWidth, setAiWidth] = useState<number | null>(null);
  useEffect(() => {
    const saved = Number(window.localStorage.getItem("ai-column-width"));
    if (Number.isFinite(saved) && saved > 0) setAiWidth(saved);
  }, []);
  useEffect(() => {
    if (aiWidth === null) {
      document.body.style.removeProperty("--ai-column-width");
    } else {
      document.body.style.setProperty("--ai-column-width", `${aiWidth}px`);
    }
  }, [aiWidth]);

  const clampAiWidth = (value: number): number =>
    Math.min(Math.max(value, 320), Math.max(320, window.innerWidth - 360));

  // Dragging the divider at the panel's edge moves the
  // boundary between the article and the panel: toward
  // the article the panel widens, away it narrows, in
  // either writing direction. The keys move it likewise —
  // the divider is a separator, and a separator is worked
  // from the keyboard as from the pointer.
  const onDividerPointerDown = (event: React.PointerEvent) => {
    if (event.button !== 0) return;
    event.preventDefault();
    const rtl = document.documentElement.dir === "rtl";
    const start = {
      x: event.clientX,
      width: aiWidth ?? sectionRef.current?.getBoundingClientRect().width ?? 0,
    };
    let last = start.width;
    const onMove = (move: PointerEvent) => {
      const delta = rtl ? move.clientX - start.x : start.x - move.clientX;
      last = clampAiWidth(start.width + delta);
      setAiWidth(last);
    };
    const onUp = () => {
      window.localStorage.setItem("ai-column-width", String(last));
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
  };

  const onDividerKeyDown = (event: React.KeyboardEvent) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    const rtl = document.documentElement.dir === "rtl";
    const step =
      (event.shiftKey ? 64 : 16) * (event.key === "ArrowLeft" ? 1 : -1);
    const current =
      aiWidth ?? sectionRef.current?.getBoundingClientRect().width ?? 0;
    const next = clampAiWidth(current + (rtl ? -step : step));
    setAiWidth(next);
    window.localStorage.setItem("ai-column-width", String(next));
  };

  // The launcher in the article header and the narrow
  // screen's bottom bar both ask the box to toggle itself
  // with this event: open when minimized, minimize when
  // open. The listener is renewed after every render, so
  // the toggle always acts on the placement as it stands.
  useEffect(() => {
    const onToggle = () => {
      if (placement === "minimized") openAssistant();
      else minimizeAssistant();
    };
    window.addEventListener("ai-assistant:toggle", onToggle);
    return () => window.removeEventListener("ai-assistant:toggle", onToggle);
  });

  // The article header's launcher is worked from here,
  // not from the button itself: the article is swapped
  // for the next page's at every in-app navigation, and
  // the button swapped in with it is inert (see
  // AiLauncher). A click on the button's class is the
  // same ask as the toggle event above. The listener is
  // renewed after every render, for the same reason.
  useEffect(() => {
    const onClick = (event: MouseEvent) => {
      const target = event.target;
      if (target instanceof Element && target.closest(".ai-launcher")) {
        if (placement === "minimized") openAssistant();
        else minimizeAssistant();
      }
    };
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  });

  // The bar's home button, pressed on the home page
  // itself, asks the box to put itself away with this
  // event: showing the home article means clearing what
  // stands over it. It is a minimize, not a toggle — a
  // window already away stays away.
  useEffect(() => {
    const onMinimize = () => minimizeAssistant();
    window.addEventListener("ai-assistant:minimize", onMinimize);
    return () =>
      window.removeEventListener("ai-assistant:minimize", onMinimize);
  });

  // A tap on the article itself while the window floats
  // puts the window away: the reader has turned back to
  // the article, and the window's own minimize button is
  // not the only way to dismiss it. The docked panel and
  // the full screen are the page's own layout, not a layer
  // over it, and no tap dismisses them — their controls
  // put them away. Where the dismissal
  // belongs depends on the screen. On a wide screen it
  // belongs to every empty part of the page — the
  // article, the header, both sidebars, the footer: the
  // window floats over a page that lies open around it,
  // and a press on any bare part of it is a turning
  // back. On a narrow screen it belongs to the article
  // and to the site header's empty ground alone — the
  // header stands at the article's head, and a tap on
  // its bare part is the same turning back — because
  // there the frame's other parts carry the layers'
  // own dealings (see lib/layers.ts). Neither screen
  // dismisses on a tap on something that acts — a link
  // above all, a button, a field, the header's own home
  // link and language button among them — which is that
  // thing's business, not a dismissal: following a link
  // carries the window along, as a navigation should.
  // A tap is a press that ends where it began,
  // soon after it began, with the page unmoved: a swipe
  // that scrolls the page begins with a press too, but
  // it is a scroll, not a tap, and leaves the window
  // standing — the reader is reading the page alongside
  // it, not turning away from the window. (A scrollbar
  // drag gives the page no press at all, and leaves it
  // standing likewise.) Two layers standing over the
  // article close one at a time, the one opened most
  // recently first (see lib/layers.ts): while the narrow
  // screen's menu drawer is open, a tap on the article
  // puts this window away only if the window was opened
  // after the drawer — if the drawer is the more recent,
  // the tap is the drawer's, and its own dismissal takes
  // it on the click that follows. A second tap, with the
  // more recent layer already gone, puts the other away.
  // Presses inside the window are
  // the window's own business, and the bottom bar's AI
  // button is left alone — it toggles the window itself,
  // and a dismissal here would fight the toggle. Only
  // the primary button counts: a right-click raises a
  // menu of its own and dismisses nothing.
  useEffect(() => {
    if (placement !== "floating") return;
    let tapStart: {
      x: number;
      y: number;
      scrollY: number;
      time: number;
    } | null = null;
    const eligible = (target: EventTarget | null): boolean => {
      if (!(target instanceof Element)) return false;
      if (windowRef.current?.contains(target)) return false;
      if (target.closest(".bottom-bar__button--ai")) return false;
      if (
        target.closest(
          "a[href], button, input, textarea, select, summary, label",
        )
      ) {
        return false;
      }
      if (
        window.matchMedia("(max-width: 60rem)").matches &&
        !target.closest(".main, .header")
      ) {
        return false;
      }
      return true;
    };
    const onPointerDown = (event: PointerEvent) => {
      if (event.button !== 0 || !eligible(event.target)) {
        tapStart = null;
        return;
      }
      tapStart = {
        x: event.clientX,
        y: event.clientY,
        scrollY: window.scrollY,
        time: Date.now(),
      };
    };
    const onPointerUp = (event: PointerEvent) => {
      const start = tapStart;
      tapStart = null;
      if (!start || !eligible(event.target)) return;
      if (Date.now() - start.time > 500) return;
      if (Math.abs(event.clientX - start.x) > 10) return;
      if (Math.abs(event.clientY - start.y) > 10) return;
      if (window.scrollY !== start.scrollY) return;
      if (
        document.querySelector<HTMLDetailsElement>(".left-sidebar > details")
          ?.open &&
        mostRecentLayer() !== "ai"
      ) {
        return;
      }
      minimizeAssistant();
    };
    const onPointerCancel = () => {
      tapStart = null;
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("pointerup", onPointerUp);
    document.addEventListener("pointercancel", onPointerCancel);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("pointerup", onPointerUp);
      document.removeEventListener("pointercancel", onPointerCancel);
    };
  }, [placement]);

  // Dragging any empty part of the window moves it: the
  // heading, the window's own padding, the conversation's
  // empty ground, the form's frame around its field. What
  // acts or holds content is not a handle — the controls,
  // the input, a link, and the messages themselves keep
  // their own business (a message can still be selected),
  // the resize handles resize, and the conversation's
  // scrollbar still scrolls the conversation. The window
  // is kept partly on screen however far it is dragged.
  const onWindowPointerDown = (event: React.PointerEvent) => {
    if (event.button !== 0) return;
    const target = event.target as Element;
    if (
      target.closest(
        "button, textarea, input, select, a, label, .ai-assistant__resize, .ai-assistant__message",
      )
    ) {
      return;
    }
    const logElement = target.closest<HTMLElement>(".ai-assistant__log-view");
    if (logElement && target === logElement) {
      const logBox = logElement.getBoundingClientRect();
      if (event.clientX > logBox.left + logElement.clientWidth) return;
    }
    const box = windowRef.current?.getBoundingClientRect();
    if (!box) return;
    const offset = { x: event.clientX - box.left, y: event.clientY - box.top };
    const onMove = (move: PointerEvent) => {
      setRect((previous) => ({
        ...previous,
        width: box.width,
        height: box.height,
        left: Math.min(
          Math.max(move.clientX - offset.x, 80 - box.width),
          window.innerWidth - 80,
        ),
        top: Math.min(
          Math.max(move.clientY - offset.y, 0),
          window.innerHeight - 40,
        ),
      }));
    };
    const onUp = () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
  };

  // The handles on the window's edges and corners resize
  // it. A handle moves its
  // own edge and holds the opposite one still. A size
  // keeps a minimum the form needs, and growth stops at
  // the screen's edge: a window is never enlarged past
  // the page, however far its handle is dragged. Moving
  // the window itself is freer — its drag keeps only a
  // part of it on screen.
  type ResizeHandle =
    | "top-left"
    | "top"
    | "top-right"
    | "right"
    | "bottom-right"
    | "bottom"
    | "bottom-left"
    | "left";
  const resizeHandles: ResizeHandle[] = [
    "top-left",
    "top",
    "top-right",
    "right",
    "bottom-right",
    "bottom",
    "bottom-left",
    "left",
  ];
  const onResizePointerDown =
    (handle: ResizeHandle) => (event: React.PointerEvent) => {
      event.preventDefault();
      const start = { x: event.clientX, y: event.clientY, rect };
      const right = start.rect.left + start.rect.width;
      const bottom = start.rect.top + start.rect.height;
      const clampSize = (value: number, min: number, max: number) =>
        Math.max(min, Math.min(value, Math.max(min, max)));
      const onMove = (move: PointerEvent) => {
        const dx = move.clientX - start.x;
        const dy = move.clientY - start.y;
        let { left, top, width, height } = start.rect;
        if (handle.includes("left")) {
          width = clampSize(start.rect.width - dx, 260, right);
          left = right - width;
        } else if (handle.includes("right")) {
          width = clampSize(
            start.rect.width + dx,
            260,
            Math.min(window.innerWidth - start.rect.left, window.innerWidth),
          );
        }
        if (handle.includes("top")) {
          height = clampSize(start.rect.height - dy, 200, bottom);
          top = bottom - height;
        } else if (handle.includes("bottom")) {
          height = clampSize(
            start.rect.height + dy,
            200,
            Math.min(window.innerHeight - start.rect.top, window.innerHeight),
          );
        }
        setRect({ left, top, width, height });
      };
      const onUp = () => {
        window.removeEventListener("pointermove", onMove);
        window.removeEventListener("pointerup", onUp);
        window.removeEventListener("pointercancel", onUp);
      };
      window.addEventListener("pointermove", onMove);
      window.addEventListener("pointerup", onUp);
      window.addEventListener("pointercancel", onUp);
    };

  // The heading's controls and the conversation are the
  // same in every form the box takes; only the controls
  // differ, as the forms do. The icons are Lucide's, in
  // the heading's own line weight.
  const iconProps = {
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.75,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": true,
  } as const;

  const minimizeIcon = (
    <svg {...iconProps}>
      <path d="M6 9l6 6 6-6" />
    </svg>
  );
  const floatIcon = (
    <svg {...iconProps}>
      <path d="M21 9V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v10c0 1.1.9 2 2 2h4" />
      <rect width="10" height="7" x="12" y="13" rx="2" />
    </svg>
  );
  const dockIcon = (
    <svg {...iconProps}>
      <rect width="18" height="18" x="3" y="3" rx="2" />
      <path d="M15 3v18" />
    </svg>
  );
  const fullScreenIcon = (
    <svg {...iconProps}>
      <path d="M8 3H5a2 2 0 0 0-2 2v3" />
      <path d="M21 8V5a2 2 0 0 0-2-2h-3" />
      <path d="M3 16v3a2 2 0 0 0 2 2h3" />
      <path d="M16 21h3a2 2 0 0 0 2-2v-3" />
    </svg>
  );

  const controlButton = (
    label: string,
    onClick: () => void,
    icon: ReactNode,
  ) => (
    <button
      type="button"
      className="ai-assistant__control"
      aria-label={label}
      onClick={onClick}
    >
      {icon}
    </button>
  );

  const heading = (controls: ReactNode) => (
    <div className="ai-assistant__heading">
      <h2 className="ai-assistant__title">
        <PandaIcon />
      </h2>
      <div className="ai-assistant__controls">{controls}</div>
    </div>
  );

  const conversation = (
    <>
      <div className="ai-assistant__log">
        <div className="ai-assistant__log-view" ref={logRef}>
          {log.map((message, index) => (
            <p
              key={index}
              className={`ai-assistant__message ai-assistant__message--${message.role}`}
            >
              {message.content}
            </p>
          ))}
        </div>
      </div>
      <p className="ai-assistant__status" hidden={status === null}>
        {status}
      </p>
      {mounted && (
        <form className="ai-assistant__form" onSubmit={onSubmit}>
          <textarea
            className="ai-assistant__input"
            placeholder={strings.message}
            rows={1}
            value={draftText}
            onChange={(event) => setDraftText(event.target.value)}
            onKeyDown={onInputKeyDown}
          />
          <button
            className="ai-assistant__send"
            type="submit"
            disabled={busy || draftText.trim() === ""}
            aria-label={strings.send}
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <path d="M12 19V5M5 12l7-7 7 7" />
            </svg>
          </button>
        </form>
      )}
    </>
  );

  return (
    <section
      ref={sectionRef}
      className="ai-assistant"
      data-summarize={strings.summarize}
      data-loading={strings.loading}
      data-send={strings.send}
      data-unsupported={strings.unsupported}
      data-error={strings.error}
      data-message={strings.message}
    >
      {effectivePlacement === "docked" ||
      effectivePlacement === "fullscreen" ? (
        <div className="ai-assistant__panel">
          {heading(
            <>
              {effectivePlacement === "docked" ? (
                <>
                  {controlButton("Float", floatAssistant, floatIcon)}
                  {controlButton(
                    "Full screen",
                    fullScreenAssistant,
                    fullScreenIcon,
                  )}
                </>
              ) : (
                <>
                  {controlButton("Float", floatAssistant, floatIcon)}
                  {!narrowScreen &&
                    controlButton("Dock", dockAssistant, dockIcon)}
                </>
              )}
              {controlButton("Minimize", minimizeAssistant, minimizeIcon)}
            </>,
          )}
          {conversation}
          {effectivePlacement === "docked" && (
            <div
              className="ai-assistant__divider"
              role="separator"
              aria-orientation="vertical"
              aria-label="Assistant panel width"
              tabIndex={0}
              onPointerDown={onDividerPointerDown}
              onKeyDown={onDividerKeyDown}
            />
          )}
        </div>
      ) : effectivePlacement === "floating" ? (
        <div
          ref={windowRef}
          className="ai-assistant__window"
          onPointerDown={onWindowPointerDown}
          style={{
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
          }}
        >
          {heading(
            <>
              {!narrowScreen && controlButton("Dock", dockAssistant, dockIcon)}
              {controlButton(
                "Full screen",
                fullScreenAssistant,
                fullScreenIcon,
              )}
              {controlButton("Minimize", minimizeAssistant, minimizeIcon)}
            </>,
          )}
          {conversation}
          {resizeHandles.map((handle) => (
            <div
              key={handle}
              className={`ai-assistant__resize ai-assistant__resize--${handle}`}
              onPointerDown={onResizePointerDown(handle)}
            />
          ))}
        </div>
      ) : null}
    </section>
  );
}
