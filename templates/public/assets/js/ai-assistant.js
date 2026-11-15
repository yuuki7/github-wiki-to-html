"use strict";
// The AI box in an article page's right sidebar: one question
// form, answered by a small language model that runs entirely
// in the reader's browser, through WebLLM. Nothing is sent to
// a server. The library and the model are loaded when the
// reader first submits the form. The form is made here, by
// script: without script
// there is no form, rather than a form that does nothing.
// The model: small, and covered for the site's languages. Its
// answers are not checked for accuracy; the box is a reading
// aid, not a source.
const modelId = "Qwen2.5-1.5B-Instruct-q4f16_1-MLC";
// Where the box remembers which model it used last time, so
// that a model the site no longer uses can be dropped from
// the browser's cache: the cache holds one model, the
// current one.
const modelStorageKey = "ai-assistant-model";
// WebLLM itself, loaded on first use from the same CDN the site
// already uses for MathJax.
const libraryUrl = "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.88/+esm";
// The model reads at most this much of the article: its context
// window must also hold the conversation and the answer.
const articleTextLimit = 6000;
// How much of the conversation is kept, in messages. Older
// exchanges are dropped, so a long chat still fits the window.
const historyLimit = 12;
// Only article pages have the box. Other pages have nothing
// to do.
const box = document.querySelector(".ai-assistant");
if (box) {
  // The box's texts, localized by the template.
  const texts = {
    summarize: box.dataset.summarize ?? "",
    loading: box.dataset.loading ?? "",
    send: box.dataset.send ?? "",
    unsupported: box.dataset.unsupported ?? "",
    error: box.dataset.error ?? "",
  };
  // The parts of the box the script works with.
  const status = box.querySelector(".ai-assistant__status");
  const log = box.querySelector(".ai-assistant__log");
  // The question form, the box's only control. The input's
  // placeholder is the summarize request itself: submitting
  // the form empty asks for the summary.
  const form = document.createElement("form");
  form.className = "ai-assistant__form";
  const input = document.createElement("input");
  input.className = "ai-assistant__input";
  input.type = "text";
  input.placeholder = texts.summarize;
  form.append(input);
  const sendButton = document.createElement("button");
  sendButton.className = "ai-assistant__send";
  sendButton.type = "submit";
  sendButton.textContent = texts.send;
  form.append(sendButton);
  box.append(form);
  // The loaded engine, once there is one, the conversation so
  // far (without the system message), and whether the model
  // is busy loading or answering.
  let engine = null;
  let history = [];
  let busy = false;
  // The article's text, as the reader sees it, cut to the
  // limit above.
  const articleText = () =>
    (document.querySelector(".article__main")?.innerText ?? "").slice(
      0,
      articleTextLimit,
    );
  // The system message: the article, and the one instruction
  // that matters, to answer in the article's own language.
  const systemMessage = () => ({
    role: "system",
    content:
      "You are an assistant on a wiki article page. The article " +
      "is below. Summarize it when asked, and answer questions " +
      "about it. Always reply in the article's language.\n\n" +
      articleText(),
  });
  // Show a line of status text, or hide the status line.
  const showStatus = (text) => {
    status.hidden = text === null;
    if (text !== null) status.textContent = text;
  };
  // Add one message to the log and return its element, so a
  // streamed answer can grow inside it.
  const addMessage = (role, text) => {
    const element = document.createElement("p");
    element.className = `ai-assistant__message ai-assistant__message--${role}`;
    element.textContent = text;
    log.append(element);
    return element;
  };
  // Import the library and ask it whether the model is
  // already in the browser's cache. Null when the library
  // itself cannot be loaded.
  const checkCache = async () => {
    try {
      const webllm = await import(libraryUrl);
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
  const dropPreviousModel = async (webllm) => {
    let previous = null;
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
  // Create the engine from an imported library. The loading
  // progress is reported only for an uncached model: a cached
  // model loads with no progress shown at all.
  const createEngine = async (found) =>
    found.webllm.CreateMLCEngine(modelId, {
      initProgressCallback: (report) => {
        if (!found.cached) {
          showStatus(`${texts.loading} ${Math.round(report.progress * 100)}%`);
        }
      },
    });
  // Ask the model, with the article and the conversation so
  // far, and stream the answer into a new log entry.
  const generate = async (activeEngine) => {
    const bubble = addMessage("assistant", "");
    let reply = "";
    const chunks = await activeEngine.chat.completions.create({
      messages: [systemMessage(), ...history],
      stream: true,
    });
    for await (const chunk of chunks) {
      reply += chunk.choices[0]?.delta?.content ?? "";
      bubble.textContent = reply;
    }
    history.push({ role: "assistant", content: reply });
    history = history.slice(-historyLimit);
  };
  // Lock and unlock the form while the model is busy.
  const setBusy = (value) => {
    busy = value;
    input.disabled = value;
    sendButton.disabled = value;
  };
  // The form's submit: an empty input asks for the summary, as
  // the placeholder says; anything typed asks that instead. The
  // first submit loads the model. A failure shows the error
  // text and leaves the form usable, so the reader can try
  // again.
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (busy) return;
    const question = input.value.trim() || texts.summarize;
    input.value = "";
    addMessage("user", question);
    history.push({ role: "user", content: question });
    setBusy(true);
    try {
      if (!engine) {
        if (!navigator.gpu) throw new Error(texts.unsupported);
        const found = await checkCache();
        if (!found) throw new Error(texts.error);
        await dropPreviousModel(found.webllm);
        engine = await createEngine(found);
        showStatus(null);
      }
      await generate(engine);
    } catch (error) {
      history.pop();
      showStatus(
        error instanceof Error && error.message === texts.unsupported
          ? texts.unsupported
          : texts.error,
      );
    }
    setBusy(false);
  });
}
