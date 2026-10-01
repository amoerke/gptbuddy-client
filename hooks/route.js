#!/usr/bin/env node
"use strict";

/**
 * Conservative UserPromptSubmit client for the gptbuddy Codex plugin.
 * Reads a Codex hook event from stdin and emits the documented hook JSON shape.
 * It also provides local status, configuration, and dry-run commands.
 */

const crypto = require("crypto");
const fs = require("fs");
const https = require("https");
const path = require("path");
const { URL } = require("url");

const pluginRoot = process.env.GPTBUDDY_PLUGIN_ROOT
  || process.env.PLUGIN_ROOT
  || (fs.existsSync(path.join(__dirname, "config", "defaults.json")) ? __dirname : path.resolve(__dirname, ".."));
const defaultsPath = path.join(pluginRoot, "config", "defaults.json");
const dataDir = process.env.GPTBUDDY_DATA_DIR || process.env.PLUGIN_DATA || path.join(pluginRoot, ".gptbuddy-data");
const configPath = path.join(dataDir, "config.json");
const logPath = path.join(dataDir, "decisions.jsonl");
const routerUrl = process.env.GPTBUDDY_ROUTER_URL || "https://gptbuddy.dataminer.cloud/v1/route";
const clientId = process.env.GPTBUDDY_CLIENT_ID || "";
const clientSecret = process.env.GPTBUDDY_CLIENT_SECRET || "";

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function mergeConfig(defaults, override) {
  const result = { ...defaults };
  for (const [key, value] of Object.entries(override)) {
    result[key] = isObject(value) && isObject(result[key]) ? mergeConfig(result[key], value) : value;
  }
  return result;
}

function loadConfig() {
  const defaults = readJson(defaultsPath);
  try {
    if (!fs.existsSync(configPath)) {
      fs.mkdirSync(dataDir, { recursive: true });
      fs.writeFileSync(configPath, `${JSON.stringify(defaults, null, 2)}\n`, "utf8");
      return defaults;
    }
    return mergeConfig(defaults, readJson(configPath));
  } catch {
    return defaults;
  }
}

function writeConfig(config) {
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
}

function rootRoute(reason) {
  return { target: "expert", confidence: 0, needs_context: 1, reason, delegate: false };
}

function localExclusion(prompt, config) {
  if (!config.enabled) return "disabled";
  if (!prompt || prompt.trim().length < Number(config.minimum_prompt_characters)) return "too_short";
  if (prompt.trimStart().startsWith("/")) return "slash_command";
  if (!clientId || !clientSecret) return "missing_router_credentials";
  return null;
}

function validateRoute(route) {
  if (!isObject(route) || !["fast", "standard", "expert"].includes(route.target)) throw new Error("invalid target");
  if (typeof route.confidence !== "number" || route.confidence < 0 || route.confidence > 1) throw new Error("invalid confidence");
  if (typeof route.needs_context !== "number" || route.needs_context < 0 || route.needs_context > 1) throw new Error("invalid context score");
  if (typeof route.reason !== "string") throw new Error("invalid reason");
}

function callRouter(prompt, config) {
  const body = JSON.stringify({ prompt: prompt.slice(0, Number(config.max_prompt_characters)) });
  const timestamp = String(Date.now());
  const signature = crypto.createHmac("sha256", clientSecret).update(`${timestamp}.${body}`).digest("hex");
  const target = new URL(routerUrl);

  return new Promise((resolve, reject) => {
    const request = https.request({
      hostname: target.hostname,
      port: target.port || 443,
      path: `${target.pathname}${target.search}`,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
        "X-Gptbuddy-Client-Id": clientId,
        "X-Gptbuddy-Timestamp": timestamp,
        "X-Gptbuddy-Signature": signature,
      },
    }, (response) => {
      let responseBody = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => { responseBody += chunk; });
      response.on("end", () => {
        if (response.statusCode < 200 || response.statusCode >= 300) return reject(new Error(`http_${response.statusCode}`));
        try {
          resolve(JSON.parse(responseBody));
        } catch (error) {
          reject(error);
        }
      });
    });
    request.setTimeout(Number(config.request_timeout_seconds) * 1000, () => request.destroy(new Error("timeout")));
    request.on("error", reject);
    request.end(body);
  });
}

async function classify(prompt, config) {
  try {
    const route = await callRouter(prompt, config);
    validateRoute(route);
    return route;
  } catch (error) {
    return rootRoute(`router_unavailable:${error.name || "Error"}`);
  }
}

async function decide(prompt, config) {
  const excluded = localExclusion(prompt, config);
  if (excluded) return rootRoute(excluded);
  const route = await classify(prompt, config);
  const role = (config.roles || {})[route.target] || {};
  const requiredConfidence = Math.max(Number(config.delegate_confidence), Number(role.minimum_confidence || 1));
  route.delegate = ["fast", "standard"].includes(route.target)
    && route.confidence >= requiredConfidence
    && route.needs_context <= Number(config.maximum_context_need);
  if (!route.delegate) route.target = "expert";
  return route;
}

function logDecision(prompt, route, config) {
  if (!config.log_decisions) return;
  fs.mkdirSync(dataDir, { recursive: true });
  const entry = {
    timestamp: new Date().toISOString(),
    prompt_sha256: crypto.createHash("sha256").update(prompt, "utf8").digest("hex"),
    prompt_length: prompt.length,
    target: route.target,
    delegate: route.delegate,
    confidence: route.confidence,
    needs_context: route.needs_context,
    reason: route.reason,
  };
  fs.appendFileSync(logPath, `${JSON.stringify(entry)}\n`, "utf8");
}

function hookOutput(route) {
  const additionalContext = route.delegate
    ? `gptbuddy routing decision: delegate once to the \`${route.target}\` subagent role if available. confidence=${route.confidence.toFixed(2)}; context_need=${route.needs_context.toFixed(2)}. This is advisory: keep the task in the root session if it is not actually self-contained.`
    : "gptbuddy routing decision: keep_root. No delegation recommendation.";
  return { hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext } };
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let input = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => { input += chunk; });
    process.stdin.on("end", () => resolve(input));
    process.stdin.on("error", reject);
  });
}

async function main() {
  const args = process.argv.slice(2);
  const config = loadConfig();
  if (args.includes("--enable") || args.includes("--disable")) {
    config.enabled = args.includes("--enable");
    writeConfig(config);
    console.log(JSON.stringify({ enabled: config.enabled, config: configPath }));
    return;
  }
  if (args.includes("--status")) {
    console.log(JSON.stringify({ enabled: config.enabled, router_url: routerUrl, router_credentials_present: Boolean(clientId && clientSecret), config: configPath, logging: config.log_decisions }, null, 2));
    return;
  }
  const testIndex = args.indexOf("--test");
  if (testIndex !== -1) {
    const prompt = args[testIndex + 1];
    if (!prompt) throw new Error("--test needs a prompt");
    const route = await decide(prompt, config);
    logDecision(prompt, route, config);
    console.log(JSON.stringify(route, null, 2));
    return;
  }
  try {
    const event = JSON.parse(await readStdin());
    if (!event || typeof event.prompt !== "string") throw new Error("missing prompt");
    const route = await decide(event.prompt, config);
    logDecision(event.prompt, route, config);
    console.log(JSON.stringify(hookOutput(route)));
  } catch {
    console.log(JSON.stringify(hookOutput(rootRoute("hook_error"))));
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
