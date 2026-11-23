"use client";

import { useEffect, useRef, useState } from "react";

// The AI box in a page's right sidebar: one question form,
// answered by a small language model that runs entirely in
// the reader's browser, through WebLLM. Nothing is sent to a
// server. The library and the model are loaded when the
// reader first submits the form. The form is rendered once
// the component has mounted: without script there is no form,
// rather than a form that does nothing.
//
// The box is part of the app's frame, not of the page: the
// frame stays mounted while the reader moves between pages,
// so the box's own state — the question being typed above
// all — is kept by the box itself staying in place. The
// engine, once loaded, is kept in this module for the whole
// session, across in-app navigation, and the conversation is
// mirrored to session storage, so that even a full page
// load — a language switch reloads the document, whose
// <html> language differs — keeps it.

// The library's own types, for the copy loaded from the CDN
// below: the two are the same version.
type WebLLM = typeof import("@mlc-ai/web-llm");

// The engine the library creates.
type Engine = Awaited<ReturnType<WebLLM["CreateMLCEngine"]>>;

// One message in the conversation.
type Message = {
  role: "system" | "user" | "assistant";
  content: string;
};

// The box's texts, localized by the caller.
export interface AiStrings {
  summarize: string;
  loading: string;
  send: string;
  unsupported: string;
  error: string;
}

// The model: small, and covered for the site's languages. Its
// answers are not checked for accuracy; the box is a reading
// aid, not a source.
const modelId = "Qwen2.5-1.5B-Instruct-q4f16_1-MLC";

// Where the box remembers which model it used last time, so
// that a model the site no longer uses can be dropped from
// the browser's cache: the cache holds one model, the
// current one.
const modelStorageKey = "ai-assistant-model";

// Where the conversation is mirrored, against full page loads.
const historyStorageKey = "ai-assistant-history";

// WebLLM itself, loaded on first use from the same CDN the site
// already uses for MathJax. The version is pinned exactly, and
// package.json pins its @mlc-ai/web-llm devDependency to the
// same version, so the types describe the code that runs.
const libraryUrl = "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.88/+esm";

// The model reads at most this much of the article: its context
// window must also hold the conversation and the answer.
const articleTextLimit = 6000;

// How much of the conversation is kept, in messages. Older
// exchanges are dropped, so a long chat still fits the window.
const historyLimit = 12;

// The failure that means this browser cannot run the
// assistant at all, as a class of its own: the submit handler
// tells it apart from other failures by type, not by comparing
// the localized message text.
class UnsupportedError extends Error {}

// The loaded engine, once there is one, and the conversation
// so far (without the system message). Both live in the
// module, not in the component, so they survive even a full
// page load's new component.
let engine: Engine | null = null;
let history: Message[] | null = null;

const loadHistory = (): Message[] => {
  if (history) return history;
  try {
    const stored = sessionStorage.getItem(historyStorageKey);
    const parsed: unknown = stored ? JSON.parse(stored) : [];
    history = Array.isArray(parsed)
      ? parsed.filter(
          (message): message is Message =>
            typeof message === "object" &&
            message !== null &&
            ((message as Message).role === "user" ||
              (message as Message).role === "assistant") &&
            typeof (message as Message).content === "string",
        )
      : [];
  } catch {
    history = [];
  }
  return history;
};

const saveHistory = (): void => {
  try {
    sessionStorage.setItem(historyStorageKey, JSON.stringify(loadHistory()));
  } catch {
    // The mirror is not kept; the conversation still lives in
    // the module for this session.
  }
};

// Import the library and ask it whether the model is
// already in the browser's cache. Null when the library
// itself cannot be loaded.
const checkCache = async (): Promise<{
  webllm: WebLLM;
  cached: boolean;
} | null> => {
  try {
    const webllm = (await import(libraryUrl)) as WebLLM;
    let cached = false;
    try {
      cached = await webllm.hasModelInCache(modelId);
    } catch {
      cached = false;
    }
    return { webllm, cached };
  } catch {
    return null;
  }
};

// Drop the previous model from the browser's cache, when
// the site's model has changed since the last visit, and
// remember the current one. Neither a cache that cannot be
// deleted nor storage that cannot be used is worth failing
// the load over: both are simply left as they are.
const dropPreviousModel = async (webllm: WebLLM): Promise<void> => {
  let previous: string | null = null;
  try {
    previous = localStorage.getItem(modelStorageKey);
  } catch {
    previous = null;
  }
  if (previous !== null && previous !== modelId) {
    try {
      await webllm.deleteModelAllInfoInCache(previous);
    } catch {
      // The old cache stays.
    }
  }
  try {
    localStorage.setItem(modelStorageKey, modelId);
  } catch {
    // The record is not kept.
  }
};

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
  // limit above.
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
    history = conversation.slice(-historyLimit);
    saveHistory();
  };

  // The form's submit: an empty input asks for the summary, as
  // the placeholder says; anything typed asks that instead. The
  // first submit loads the model. A failure shows the error
  // text and leaves the form usable, so the reader can try
  // again.
  const onSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (busyRef.current) return;
    const question = draftText.trim() || liveStrings().summarize;
    setDraftText("");
    setLog((previous) => [...previous, { role: "user", content: question }]);
    loadHistory().push({ role: "user", content: question });
    busyRef.current = true;
    setBusy(true);
    try {
      if (!engine) {
        if (!navigator.gpu)
          throw new UnsupportedError(liveStrings().unsupported);
        const found = await checkCache();
        if (!found) throw new Error(liveStrings().error);
        await dropPreviousModel(found.webllm);
        engine = await createEngine(found);
        setStatus(null);
      }
      await generate(engine);
    } catch (error) {
      loadHistory().pop();
      saveHistory();
      setStatus(
        error instanceof UnsupportedError
          ? liveStrings().unsupported
          : liveStrings().error,
      );
    }
    busyRef.current = false;
    setBusy(false);
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
    };
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
    >
      <h2 className="ai-assistant__title">AI</h2>
      <div className="ai-assistant__log">
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
          <input
            className="ai-assistant__input"
            type="text"
            placeholder={strings.summarize}
            value={draftText}
            onChange={(event) => setDraftText(event.target.value)}
            disabled={busy}
          />
          <button className="ai-assistant__send" type="submit" disabled={busy}>
            {strings.send}
          </button>
        </form>
      )}
    </section>
  );
}
