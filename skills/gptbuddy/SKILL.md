---
name: gptbuddy
description: Follow a gptbuddy routing recommendation from the UserPromptSubmit hook, and explain or inspect its routing status when the user asks about efficient agent routing.
---

# gptbuddy routing contract

The UserPromptSubmit hook may add a `gptbuddy routing decision` to developer context.

When it recommends `fast` or `standard`:

1. Treat the recommendation as advisory and verify that the task is genuinely self-contained.
2. Delegate the whole task to exactly one subagent with the named role when subagents are available.
3. Keep the task in the root session if it needs unprovided conversation context, needs decisions from the user, is security-sensitive, or would involve overlapping edits with another agent.
4. Preserve the user's scope. Do not expose prompt text, files, secrets, or conversation history in status output.
5. Briefly disclose delegation in the final result only when a subagent actually did work.

When the recommendation is `expert` or `keep_root`, do the work in the root session. Never delegate merely to satisfy a routing recommendation.

For requests about gptbuddy itself, explain that it evaluates only the current prompt, has a conservative fail-open policy, and can be controlled locally with `node hooks/route.js --status`, `--enable`, `--disable`, or `--test "prompt"` from the plugin root.
