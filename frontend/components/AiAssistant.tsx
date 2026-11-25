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
    trimHistory();
    // Keep what is on screen in step with what survives a reload.
    setLog((previous) => previous.slice(-historyLimit));
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
    const previousLog = log;
    const question = draftText.trim() || liveStrings().summarize;
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
