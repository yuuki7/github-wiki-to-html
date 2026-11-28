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
import type { AiStrings } from "../lib/types";
import {
  dragWindow,
  emptyArrangement,
  resizeWindow,
  standingRect,
  takeSize,
  type ScreenKind,
  type WindowArrangement,
  type WindowRect,
} from "../lib/window-arrangement";
import PandaIcon from "./PandaIcon";
import { Rnd } from "react-rnd";

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
  // places are the floating window's, in viewport
  // coordinates. The box's element sits in the right
  // sidebar: minimized it is empty and the sidebar is left
  // blank, docked the stylesheet stands the sidebar itself
  // up as the panel, and floating the window leaves the
  // sidebar and floats over the page as before.
  type Placement = "minimized" | "docked" | "floating" | "fullscreen";
  const [placement, setPlacement] = useState<Placement>("minimized");
  // The floating window's arrangement — the one place
  // and the one size (see lib/window-arrangement for
  // the arrangement itself: what is the reader's, what
  // is a default, and how the screen reads it without
  // ever rewriting it).
  const [arrangement, setArrangement] =
    useState<WindowArrangement>(emptyArrangement);
  // The conversation's end stays in view: the log scrolls
  // within the window, a new message — the reader's own
  // above all — is no use below the fold, and a window
  // opened on an earlier conversation starts at its end,
  // where the latest message is.
  useEffect(() => {
    const element = logRef.current;
    if (element) element.scrollTop = element.scrollHeight;
  }, [log, placement]);

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

  // The screen's size, kept as it changes: the standing
  // place is read from it (see shownRect), so a change
  // of size is a change of the reading, rendered like
  // any other — the place itself is not touched.
  const [viewport, setViewport] = useState<{
    width: number;
    height: number;
  } | null>(null);
  useEffect(() => {
    const update = () =>
      setViewport({ width: window.innerWidth, height: window.innerHeight });
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  // The kind of screen the box is on, for the
  // arrangement's reads: the defaults are the kind's.
  const screenKind: ScreenKind = narrowScreen ? "narrow" : "wide";

  // The arrangement's writers. The reader's hand writes
  // the arrangement: a drag writes the place, a resize
  // of the window writes the size and the place it ends
  // at. The window's own standing writes the size, once
  // (see the standing effect below). Nothing else writes
  // the arrangement at all: the screen only reads it for
  // standing (see shownRect).
  const dragTo = (place: { left: number; top: number }) => {
    setArrangement((previous) => dragWindow(previous, place));
  };
  const resizeTo = (rect: WindowRect) => {
    setArrangement((previous) => resizeWindow(previous, rect));
  };

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

  // The window's standing, read from the arrangement
  // through the screen as it stands (see
  // lib/window-arrangement): the reading is made here,
  // where the window is drawn, and the library below is
  // handed the fitted standing. Until the size is taken
  // (see the standing effect below) the standing reads
  // the current screen's default size — the first frame
  // only, before the effect writes it.
  let shownRect: WindowRect = { left: 0, top: 0, width: 0, height: 0 };
  if (viewport !== null) {
    shownRect = standingRect(
      arrangement,
      viewport,
      screenKind,
      document.documentElement.dir === "rtl",
    );
  }

  // The standing takes the size, once. When the window
  // stands and the arrangement has no size yet, the size
  // is written from the screen as it is at that moment,
  // and from then on it is the arrangement's, like
  // anything the reader's hand writes: no screen, of
  // either kind, at any size, writes it again. (The
  // places are not written here: an unwritten place is
  // the screen's corner, read as the screen stands —
  // see lib/window-arrangement.)
  useEffect(() => {
    if (placement !== "floating") return;
    setArrangement((previous) =>
      takeSize(
        previous,
        { width: window.innerWidth, height: window.innerHeight },
        screenKind,
      ),
    );
  });

  // Opening the box: on a wide screen it docks, on a
  // narrow one it floats. The floating window opens at
  // the arrangement's place — the place survives
  // minimizing — and only a window the reader has never
  // placed starts from the screen's corner.
  const openAssistant = () => {
    if (narrowScreen) {
      setPlacement("floating");
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
    setPlacement("floating");
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
  // from the body's classes, and the panda button — the
  // launcher in the article header, a fresh element on
  // every page — takes its pressed state from here, on a
  // navigation as on a change of the form itself.
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
        .querySelectorAll(".ai-launcher")
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
    // drawer is that screen's own furniture, not the
    // dock's, and it is left alone.
    if (
      effectivePlacement !== "docked" &&
      effectivePlacement !== "fullscreen" &&
      !window.matchMedia("(max-width: 60rem)").matches
    ) {
      window.dispatchEvent(new Event("sidebar-menu:close"));
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

  // The article header's launcher is worked from here,
  // not from the button itself: the article is swapped
  // for the next page's at every in-app navigation, and
  // the button swapped in with it is inert (see
  // AiLauncher). A click on the button's class toggles
  // the box: open when minimized, minimize when open.
  // The listener is renewed after every render, so the
  // toggle always acts on the placement as it stands.
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
  // there the menu's drawer stands over the article
  // with a dismissal of its own. Neither screen
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
  // standing likewise.) Two layers can stand over the
  // article at once — this window and the menu's drawer
  // (see TocDrawer) — and a press puts away one of them:
  // the drawer takes its own dismissal on the press
  // itself, so a press that began with the drawer
  // standing is the drawer's, and this window leaves it
  // alone, noting whether the drawer stood when the
  // press began — by the release that judges the tap,
  // the drawer is already gone. A second press, with the
  // drawer gone, puts the window away.
  // Presses inside the window are
  // the window's own business. Only the primary button
  // counts: a right-click raises a menu of its own and
  // dismisses nothing.
  useEffect(() => {
    if (placement !== "floating") return;
    let tapStart: {
      x: number;
      y: number;
      scrollY: number;
      time: number;
    } | null = null;
    let menuStoodAtPress = false;
    const eligible = (target: EventTarget | null): boolean => {
      if (!(target instanceof Element)) return false;
      if (target.closest(".ai-assistant__window")) return false;
      if (target.closest(".sidebar-drawer__popup")) return false;
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
      menuStoodAtPress = !!document.querySelector(".sidebar-drawer__popup");
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
      if (menuStoodAtPress) return;
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
      <path d="M18 6 6 18M6 6l12 12" />
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
        // The window's dragging and resizing are react-rnd's:
        // a drag starts on any empty part of the window, and
        // what acts or holds content is not a handle — the
        // controls, the input, a link, and the messages
        // themselves are cancelled out of dragging, so a
        // message can still be selected. The bounds keep the
        // whole window on screen, where the hand-written
        // drag kept only a part of it. The frame around it
        // is the library's ground: it counts positions from
        // its parent's corner, and the box lives deep in the
        // page's grid, so a fixed frame at the viewport's own
        // corner gives it the viewport to count from. The
        // library renders its box as an inline block, so the
        // window's flex column goes to it as a style —
        // without it, the conversation spills out of the
        // window instead of scrolling inside it.
        <div className="ai-assistant__window-frame">
          <Rnd
            className="ai-assistant__window"
            style={{ display: "flex" }}
            size={{ width: shownRect.width, height: shownRect.height }}
            position={{ x: shownRect.left, y: shownRect.top }}
            minWidth={260}
            minHeight={200}
            bounds="window"
            cancel="button, textarea, input, select, a, label, .ai-assistant__message"
            onDrag={(_event, data) => {
              dragTo({ left: data.x, top: data.y });
            }}
            onResize={(_event, _direction, ref, _delta, position) => {
              resizeTo({
                left: position.x,
                top: position.y,
                width: ref.offsetWidth,
                height: ref.offsetHeight,
              });
            }}
          >
            {heading(
              <>
                {!narrowScreen &&
                  controlButton("Dock", dockAssistant, dockIcon)}
                {controlButton(
                  "Full screen",
                  fullScreenAssistant,
                  fullScreenIcon,
                )}
                {controlButton("Minimize", minimizeAssistant, minimizeIcon)}
              </>,
            )}
            {conversation}
          </Rnd>
        </div>
      ) : null}
    </section>
  );
}
