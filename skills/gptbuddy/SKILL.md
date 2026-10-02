---
name: gptbuddy
description: Follow a gptbuddy routing recommendation from the UserPromptSubmit hook, and explain or inspect its routing status when the user asks about efficient agent routing.
---

# gptbuddy routing contract

The UserPromptSubmit hook may add a `gptbuddy routing decision` to developer context.

When it recommends `fast` or `standard`:

1. Delegate the whole task to exactly one subagent with the named role when subagents are available. The router has already classified it as self-contained.
2. Keep the task in the root session only when subagents are unavailable or when an overriding system or user instruction prevents delegation.
3. Preserve the user's scope. Do not expose prompt text, files, secrets, or conversation history in status output.
4. Briefly disclose delegation in the final result only when a subagent actually did work.

When the recommendation is `expert` or `keep_root`, do the work in the root session. Never delegate merely to satisfy a routing recommendation.

For requests about gptbuddy itself, explain that it evaluates only the current prompt, has a conservative fail-open policy, and can be controlled locally with `node hooks/route.js --status`, `--enable`, `--disable`, or `--test "prompt"` from the plugin root.
