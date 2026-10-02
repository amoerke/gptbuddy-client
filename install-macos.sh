#!/usr/bin/env bash
# Installs the gptbuddy Codex hooks for the current macOS user.
set -euo pipefail

readonly DEFAULT_ROUTER_URL="https://gptbuddy.dataminer.cloud/v1/route"
repository="amoerke/gptbuddy-client"
ref="main"
router_url="${GPTBUDDY_ROUTER_URL:-$DEFAULT_ROUTER_URL}"
client_id="${GPTBUDDY_CLIENT_ID:-}"
client_secret="${GPTBUDDY_CLIENT_SECRET:-}"

usage() {
  printf '%s\n' "Verwendung: $0 [--client-id ID] [--client-secret SECRET] [--router-url URL] [--repository INHABER/REPOSITORY] [--ref REF]"
}

while (($#)); do
  case "$1" in
    --client-id) client_id="${2:?Wert für --client-id fehlt}"; shift 2 ;;
    --client-secret) client_secret="${2:?Wert für --client-secret fehlt}"; shift 2 ;;
    --router-url) router_url="${2:?Wert für --router-url fehlt}"; shift 2 ;;
    --repository) repository="${2:?Wert für --repository fehlt}"; shift 2 ;;
    --ref) ref="${2:?Wert für --ref fehlt}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unbekannte Option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  printf '%s\n' 'Das Repository muss das Format inhaber/repository haben.' >&2
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  printf '%s\n' 'Node.js wird benötigt. Installiere die aktuelle Node.js-LTS-Version von https://nodejs.org/en/download und starte dieses Installationsskript erneut.' >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' 'curl wird benötigt (bei aktuellen macOS-Versionen ist es bereits enthalten).' >&2
  exit 1
fi

readonly node_bin="$(command -v node)"
readonly install_dir="$HOME/.gptbuddy"
readonly config_dir="$install_dir/config"
readonly credentials_file="$install_dir/credentials.json"
readonly hooks_dir="$HOME/.codex"
readonly hooks_file="$hooks_dir/hooks.json"
readonly launch_agents_dir="$HOME/Library/LaunchAgents"
readonly launch_agent="$launch_agents_dir/cloud.dataminer.gptbuddy-environment.plist"
readonly uid="$(id -u)"

# Reuse credentials from a prior installation unless explicitly supplied.
if [[ -f "$credentials_file" ]] && [[ -z "$client_id" || -z "$client_secret" ]]; then
  stored_credentials="$("$node_bin" -e '
    const fs = require("fs");
    try {
      const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      process.stdout.write(`${value.client_id || ""}\n${value.client_secret || ""}`);
    } catch { process.exit(0); }
  ' "$credentials_file")"
  stored_id="${stored_credentials%%$'\n'*}"
  stored_secret="${stored_credentials#*$'\n'}"
  [[ -n "$client_id" ]] || client_id="$stored_id"
  [[ -n "$client_secret" ]] || client_secret="$stored_secret"
fi

if [[ -z "$client_id" ]]; then
  read -r -p 'gptbuddy Client-ID: ' client_id
fi
if [[ -z "$client_secret" ]]; then
  read -r -s -p 'gptbuddy Client-Secret: ' client_secret
  printf '\n'
fi
if [[ -z "$client_id" || -z "$client_secret" ]]; then
  printf '%s\n' 'Eine Client-ID und ein Client-Secret werden benötigt.' >&2
  exit 1
fi
if [[ "$client_id" == *$'\n'* || "$client_secret" == *$'\n'* ]]; then
  printf '%s\n' 'Client-ID und Client-Secret dürfen keine Zeilenumbrüche enthalten.' >&2
  exit 1
fi

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/gptbuddy.XXXXXX")"
cleanup() { rm -rf "$temporary_dir"; }
trap cleanup EXIT

base_url="https://raw.githubusercontent.com/$repository/$ref"
download() {
  curl --fail --location --silent --show-error "$1" --output "$2"
}

printf '%s\n' 'gptbuddy-Komponenten werden heruntergeladen ...'
download "$base_url/hooks/route.js" "$temporary_dir/route.js"
download "$base_url/hooks/observe-subagent.js" "$temporary_dir/observe-subagent.js"
download "$base_url/config/defaults.json" "$temporary_dir/defaults.json"
"$node_bin" --check "$temporary_dir/route.js"
"$node_bin" --check "$temporary_dir/observe-subagent.js"
"$node_bin" -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$temporary_dir/defaults.json"

mkdir -p "$install_dir" "$config_dir" "$hooks_dir" "$launch_agents_dir"
chmod 700 "$install_dir"
install -m 600 "$temporary_dir/route.js" "$install_dir/route.js"
install -m 600 "$temporary_dir/observe-subagent.js" "$install_dir/observe-subagent.js"
install -m 600 "$temporary_dir/defaults.json" "$config_dir/defaults.json"

# Keep secrets out of hooks.json. The LaunchAgent restores them for GUI-launched
# Codex after login; launchctl setenv makes them immediately available as well.
"$node_bin" -e '
  const fs = require("fs");
  const path = require("path");
  const target = process.argv[1];
  const value = { client_id: process.argv[2], client_secret: process.argv[3], router_url: process.argv[4], plugin_root: process.argv[5] };
  const temporary = `${target}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, target);
' "$credentials_file" "$client_id" "$client_secret" "$router_url" "$install_dir"
chmod 600 "$credentials_file"

cat > "$temporary_dir/set-environment.js" <<'NODE'
"use strict";
const { spawnSync } = require("child_process");
const fs = require("fs");
const credentials = JSON.parse(fs.readFileSync(require("path").join(__dirname, "credentials.json"), "utf8"));
for (const [name, value] of Object.entries({
  GPTBUDDY_ROUTER_URL: credentials.router_url,
  GPTBUDDY_CLIENT_ID: credentials.client_id,
  GPTBUDDY_CLIENT_SECRET: credentials.client_secret,
  GPTBUDDY_PLUGIN_ROOT: credentials.plugin_root,
})) {
  const result = spawnSync("/bin/launchctl", ["setenv", name, String(value)], { stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status || 1);
}
NODE
"$node_bin" --check "$temporary_dir/set-environment.js"
install -m 600 "$temporary_dir/set-environment.js" "$install_dir/set-environment.js"

cat > "$temporary_dir/gptbuddy-environment.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>cloud.dataminer.gptbuddy-environment</string>
  <key>ProgramArguments</key><array><string>$node_bin</string><string>$install_dir/set-environment.js</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
PLIST
plutil -lint "$temporary_dir/gptbuddy-environment.plist" >/dev/null
install -m 600 "$temporary_dir/gptbuddy-environment.plist" "$launch_agent"

"$node_bin" -e '
  const fs = require("fs");
  const hooksFile = process.argv[1], route = process.argv[2], observer = process.argv[3];
  let config = {};
  if (fs.existsSync(hooksFile)) config = JSON.parse(fs.readFileSync(hooksFile, "utf8"));
  if (!config || typeof config !== "object" || Array.isArray(config)) throw new Error("hooks.json must be a JSON object");
  if (!config.hooks || typeof config.hooks !== "object" || Array.isArray(config.hooks)) config.hooks = {};
  function ensure(event, command, statusMessage, timeout, additionalContextLimit) {
    const groups = Array.isArray(config.hooks[event]) ? config.hooks[event] : [];
    for (const group of groups) for (const handler of (Array.isArray(group.hooks) ? group.hooks : [])) {
      if (handler.command === command) { Object.assign(handler, { timeout, async: false }); return; }
    }
    const handler = { type: "command", command, timeout, async: false };
    if (statusMessage) handler.statusMessage = statusMessage;
    if (additionalContextLimit !== undefined) handler.additionalContextLimit = additionalContextLimit;
    groups.push({ hooks: [handler] }); config.hooks[event] = groups;
  }
  ensure("UserPromptSubmit", `node "${route}"`, "gptbuddy prüft die Aufgabe", 6, 300);
  ensure("SubagentStart", `node "${observer}"`, "", 3);
  ensure("SubagentStop", `node "${observer}"`, "", 3);
  const temporary = `${hooksFile}.gptbuddy.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(config, null, 2)}\n`, "utf8");
  fs.renameSync(temporary, hooksFile);
' "$hooks_file" "$install_dir/route.js" "$install_dir/observe-subagent.js"

# Make the settings available now and register the login-time restoration job.
"$node_bin" "$install_dir/set-environment.js"
launchctl bootstrap "gui/$uid" "$launch_agent" 2>/dev/null || true

printf '%s\n' 'gptbuddy wurde erfolgreich installiert.'
printf '%s\n' 'Bitte Codex vollständig schließen und erneut öffnen. Prüfe und bestätige den neuen Hook, wenn Codex danach fragt.'
printf 'Installierter Hook: %s\n' "$install_dir/route.js"
