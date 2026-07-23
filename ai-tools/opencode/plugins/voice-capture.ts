import type { Plugin } from '@opencode-ai/plugin';

/**
 * Feed Tom's opencode prompts into the private voice corpus.
 *
 * Same capture path as the Claude Code UserPromptSubmit hook and the codex
 * user_prompt_submit hook — this plugin exists only because opencode has no
 * equivalent hook slot. All scrubbing, filtering and dedupe live in the shared
 * `bin/voice-capture` script; this just hands it the text.
 *
 * Never blocks a turn: failures are swallowed, and the capture runs detached.
 */
export const VoiceCapturePlugin: Plugin = async ({ $ }) => {
  const capture = async (text: string) => {
    if (!text || !text.trim()) return;
    try {
      await $`echo ${JSON.stringify({ prompt: text })} | VOICE_CAPTURE_SOURCE=opencode voice-capture`.quiet();
    } catch {
      // capture is best-effort; a broken corpus write must never break a prompt
    }
  };

  return {
    event: async ({ event }) => {
      if (event.type !== 'message.updated') return;
      const info: any = (event as any).properties?.info;
      if (!info || info.role !== 'user') return;
      const parts: any[] = info.parts ?? [];
      const text = parts
        .filter((p) => p?.type === 'text' && typeof p.text === 'string')
        .map((p) => p.text)
        .join('\n');
      await capture(text);
    },
  };
};
