"use strict";
// Tinycast / Raycast no-view command (interval 5m): runs claude-usage.sh from the scripts
// folder (preference, default ~/Documents/dotfiles/raycast/ai-usage) and shows its first output
// line as this command's subtitle. All logic lives in the shell script; this is a thin wrapper.
// Self-contained plain CommonJS (Tinycast copies only <command>.js + assets), no build step.
const SCRIPT = "claude-usage.sh";

const { execFile } = require("child_process");
const { getPreferenceValues, updateCommandMetadata } = require("@raycast/api");

module.exports.default = async function command() {
  const home = process.env.HOME || "";
  const folder = ((getPreferenceValues() || {}).scriptsFolder || "~/Documents/dotfiles/raycast/ai-usage")
    .trim().replace(/^~(?=\/|$)/, home).replace(/\/+$/, "");
  const line = await new Promise((resolve) => {
    execFile("/bin/bash", [`${folder}/${SCRIPT}`],
      { timeout: 90000, env: { HOME: home, LANG: "en_US.UTF-8", AI_USAGE_COLOR: "0" } },
      (error, stdout) => {
        const first = String(stdout || "").split("\n")[0].trim();
        resolve(first || (error ? `error: ${error.message}`.slice(0, 80) : "no output"));
      });
  });
  await updateCommandMetadata({ subtitle: line });
};
