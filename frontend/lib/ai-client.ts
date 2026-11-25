// Client-side WebLLM engine, cache management, and session history
// for the AI assistant sidebar. Kept in a module so the loaded
// engine and conversation survive in-app navigation and full reloads.

export type WebLLM = typeof import("@mlc-ai/web-llm");
export type Engine = Awaited<ReturnType<WebLLM["CreateMLCEngine"]>>;

export type Message = {
  role: "system" | "user" | "assistant";
  content: string;
};

export const modelId = "Qwen2.5-1.5B-Instruct-q4f16_1-MLC";
const modelStorageKey = "ai-assistant-model";
const historyStorageKey = "ai-assistant-history";
const libraryUrl = "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.88/+esm";

export const articleTextLimit = 6000;
export const historyLimit = 12;

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
