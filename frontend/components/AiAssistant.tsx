"use client";

import { useEffect, useRef, useState } from "react";
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

// The AI box: one question form, answered by a small
// language model that runs entirely in the reader's browser,
// through WebLLM. Nothing is sent to a server. The library
// and the model are loaded when the reader first submits the
// form. The form is rendered once the component has mounted:
// without script there is no form, rather than a form that
// does nothing.
//
// The box starts minimized: a launcher button framed at a
// page's bottom right corner, and nothing else. The button
// opens the conversation as a floating window that grows
// out of that corner; its default place is the bottom
// right, with a margin from the page's edges. The reader
// can drag the window by its heading and put it anywhere on
// the screen, resize it from any edge or corner, and centre
// it from the heading; minimizing it back to the button
// keeps where it was, so it opens again where it left off,
// and the default place is where a freshly loaded page
// puts it. The article never moves for it: the window
// floats over the page, and only the window moves.
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

  // The window's placement: minimized to its launcher
  // button, or floating where the reader has put it.
  // The placement is the box's own state, so it
  // is kept like the rest of the box's state while the
  // reader moves between pages. The rectangle is in
  // viewport coordinates. The box's element itself stays
  // where the layout puts it and takes no room: the button
  // and the window both float over the page, so the right
  // sidebar the element sits in is left blank.
  interface WindowRect {
    left: number;
    top: number;
    width: number;
    height: number;
  }
  const [placement, setPlacement] = useState<"minimized" | "floating">(
    "minimized",
  );
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

  // The window's default place: the screen's bottom right
  // corner — the bottom left in a right-to-left language —
  // a margin in from the edges, at a size a conversation
  // can start in, cut down to fit a smaller screen.
  const homeRect = (): WindowRect => {
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

  // The launcher's click: the window opens where it last
  // was. Its rectangle survives minimizing, so only an
  // opening on a freshly loaded page — no rectangle yet —
  // starts from the default place.
  const openWindow = () => {
    if (rect.width === 0) setRect(homeRect());
    setPlacement("floating");
  };

  // Minimizing keeps the window's place and size: the
  // reader's arrangement is worth more than the default
  // place, and the default is still there — it is where
  // a freshly loaded page opens the window.
  const minimizeWindow = () => {
    setPlacement("minimized");
  };

  // Dragging the heading moves the window. The window is
  // kept partly on screen however far it is dragged.
  const onHeadingPointerDown = (event: React.PointerEvent) => {
    if ((event.target as Element).closest("button")) return;
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
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
  };

  // The handles on the window's edges and corners resize
  // it. A handle moves its
  // own edge and holds the opposite one still. A size
  // keeps a minimum the form needs, and growth stops at
  // the screen's edge: a window is never enlarged past
  // the page, however far its handle is dragged. Moving
  // the window itself is freer — the heading's drag keeps
  // only a part of it on screen.
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
      };
      window.addEventListener("pointermove", onMove);
      window.addEventListener("pointerup", onUp);
    };

  // The centred window's place and size: over the page's
  // central column, a margin in from the screen's top and
  // bottom. The column is where the reading happens; the
  // window covers it, centred, and no more of the page
  // than that.
  const columnRect = (): WindowRect => {
    const margin = 24;
    const main = document.querySelector(".main")?.getBoundingClientRect();
    if (!main) {
      return {
        left: margin,
        top: margin,
        width: window.innerWidth - margin * 2,
        height: window.innerHeight - margin * 2,
      };
    }
    return {
      left: main.left,
      top: margin,
      width: main.width,
      height: window.innerHeight - margin * 2,
    };
  };

  // The heading's other button takes the window to that
  // fixed size and centres it there: larger than the
  // default size, and the same whatever size the reader
  // had given the window. It is always there, beside the
  // minimize button: the window has no modes for it to
  // change with.
  const centerWindow = () => {
    setRect(columnRect());
  };

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
      {placement === "minimized" ? (
        <button
          type="button"
          className="ai-assistant__launcher"
          aria-label="AI"
          onClick={openWindow}
        >
          <span aria-hidden="true">🧸</span>
        </button>
      ) : (
        <div
          ref={windowRef}
          className="ai-assistant__window"
          style={{
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
          }}
        >
          <div
            className="ai-assistant__heading"
            onPointerDown={onHeadingPointerDown}
          >
            <h2 className="ai-assistant__title">🧸</h2>
            <div className="ai-assistant__controls">
              <button
                type="button"
                className="ai-assistant__control"
                aria-label="Center"
                onClick={centerWindow}
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  <path d="M3 7a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-10" />
                  <path
                    d="M11 11h2v2h-2v-2"
                    fill="currentColor"
                    stroke="none"
                  />
                </svg>
              </button>
              <button
                type="button"
                className="ai-assistant__control"
                aria-label="Minimize"
                onClick={minimizeWindow}
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </button>
            </div>
          </div>
          <div className="ai-assistant__log" ref={logRef}>
            {log.map((message, index) => (
              <p
                key={index}
                className={`ai-assistant__message ai-assistant__message--${message.role}`}
              >
                {message.content}
              </p>
            ))}
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
          {resizeHandles.map((handle) => (
            <div
              key={handle}
              className={`ai-assistant__resize ai-assistant__resize--${handle}`}
              onPointerDown={onResizePointerDown(handle)}
            />
          ))}
        </div>
      )}
    </section>
  );
}
