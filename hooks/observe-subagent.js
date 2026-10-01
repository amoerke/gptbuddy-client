#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const pluginRoot = process.env.GPTBUDDY_PLUGIN_ROOT
  || process.env.PLUGIN_ROOT
  || (fs.existsSync(path.join(__dirname, "config", "defaults.json")) ? __dirname : path.resolve(__dirname, ".."));
const dataDir = process.env.GPTBUDDY_DATA_DIR || process.env.PLUGIN_DATA || path.join(pluginRoot, ".gptbuddy-data");
const logPath = path.join(dataDir, "subagents.jsonl");
const showNotices = process.env.GPTBUDDY_SHOW_SUBAGENT_NOTICES === "true";

async function main() {
  let raw = "";
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) raw += chunk;
  const event = JSON.parse(raw);
  if (!["SubagentStart", "SubagentStop"].includes(event.hook_event_name)) return console.log("{}");

  fs.mkdirSync(dataDir, { recursive: true });
  const entry = {
    timestamp: new Date().toISOString(),
    event: event.hook_event_name,
    agent_id: event.agent_id || null,
    agent_type: event.agent_type || null,
    model: event.model || null,
  };
  fs.appendFileSync(logPath, `${JSON.stringify(entry)}\n`, "utf8");

  if (!showNotices) return console.log("{}");
  const action = entry.event === "SubagentStart" ? "gestartet" : "beendet";
  const agentType = entry.agent_type || "unbekannt";
  const model = entry.model || "unbekannt";
  console.log(JSON.stringify({ systemMessage: `gptbuddy: Subagent ${agentType} mit Modell ${model} ${action}.` }));
}

main().catch(() => console.log("{}"));
