// The WebLLM side of the AI assistant box (components/
// AiAssistant.tsx): the loaded engine, the model's cache, and
// the conversation. All three live in this module, not in the
// component, so they survive in-app navigation and even a full
// page load's new component; the conversation is also mirrored
// to session storage, against full page loads.

// The library's own types, for the copy loaded from the CDN
// below: package.json pins its @mlc-ai/web-llm devDependency
// to the same version, so the types describe the code that runs.
export type WebLLM = typeof import("@mlc-ai/web-llm");
export type Engine = Awaited<ReturnType<WebLLM["CreateMLCEngine"]>>;

// One message in the conversation.
export type Message = {
  role: "system" | "user" | "assistant";
  content: string;
};

// The model: small, and covered for the site's languages. Its
// answers are not checked for accuracy; the box is a reading
// aid, not a source.
export const modelId = "Qwen2.5-1.5B-Instruct-q4f16_1-MLC";

// Where the box remembers which model it used last time, so
// that a model the site no longer uses can be dropped from
// the browser's cache: the cache holds one model, the current one.
const modelStorageKey = "ai-assistant-model";

// Where the conversation is mirrored, against full page loads.
const historyStorageKey = "ai-assistant-history";

// WebLLM itself, loaded on first use from the same CDN the
// site already uses for MathJax. The version is pinned exactly.
const libraryUrl = "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.88/+esm";

// The model reads at most this much of the article: its context
// window must also hold the conversation and the answer.
export const articleTextLimit = 6000;

// How much of the conversation is kept, in messages. Older
// exchanges are dropped, so a long chat still fits the window.
export const historyLimit = 12;

// The failure that means this browser cannot run the assistant
// at all, as a class of its own: the submit handler tells it
// apart from other failures by type, not by comparing the
// localized message text.
export class UnsupportedError extends Error {}

let engine: Engine | null = null;
let history: Message[] | null = null;

export function getEngine(): Engine | null {
  return engine;
}

export function setEngine(next: Engine | null): void {
  engine = next;
}

export function loadHistory(): Message[] {
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
}

export function trimHistory(): Message[] {
  const current = loadHistory();
  if (current.length > historyLimit) {
    history = current.slice(-historyLimit);
  }
  return history ?? current;
}

export function saveHistory(): void {
  try {
    sessionStorage.setItem(historyStorageKey, JSON.stringify(loadHistory()));
  } catch {
    // The mirror is not kept; the conversation still lives in
    // the module for this session.
  }
}

// Import the library and ask it whether the model is already
// in the browser's cache. Null when the library itself cannot
// be loaded.
export async function checkCache(): Promise<{
  webllm: WebLLM;
  cached: boolean;
} | null> {
  try {
    const webllm = (await import(
      /* webpackIgnore: true */ libraryUrl
    )) as WebLLM;
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
}

// Drop the previous model from the browser's cache, when the
// site's model has changed since the last visit, and remember
// the current one. Neither a cache that cannot be deleted nor
// storage that cannot be used is worth failing the load over:
// both are simply left as they are.
export async function dropPreviousModel(webllm: WebLLM): Promise<void> {
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
}
