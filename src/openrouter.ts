import "dotenv/config";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

export type ChatMessage = { role: "system" | "user" | "assistant"; content: string };
export type ChatOptions = { model?: string; temperature?: number; responseFormatJson?: boolean };

export async function chat(messages: ChatMessage[], opts: ChatOptions = {}): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) throw new Error("Manca OPENROUTER_API_KEY nel file .env");

  const model = opts.model ?? process.env.CURATOR_MODEL ?? "openai/gpt-4o-mini";

  const body: Record<string, unknown> = {
    model,
    messages,
    temperature: opts.temperature ?? 0.8,
  };
  if (opts.responseFormatJson) body.response_format = { type: "json_object" };

  const res = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "http://localhost",
      "X-Title": "Curatore Personale",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Errore OpenRouter ${res.status}: ${text}`);
  }

  const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
  return data.choices?.[0]?.message?.content ?? "";
}