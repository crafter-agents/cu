// OS detection + the agnostic command mapping. Pure functions, fully testable.

export type OS = "macos" | "linux" | "windows" | "unknown";

export function detectOS(platform: NodeJS.Platform = process.platform): OS {
  if (platform === "darwin") return "macos";
  if (platform === "linux") return "linux";
  if (platform === "win32") return "windows";
  return "unknown";
}

/** How a modifier chord maps to each OS input plane. Pure. */
export function chordToOS(os: OS, chord: string): { cmd: string[]; note?: string } {
  const parts = chord.toLowerCase().split("+");
  const base = parts[parts.length - 1]!;
  const mods = parts.slice(0, -1);
  const has = (m: string) => mods.some((x) => x === m || (m === "cmd" && x === "meta"));

  if (os === "macos") {
    const using: string[] = [];
    if (has("cmd")) using.push("command down");
    if (has("ctrl")) using.push("control down");
    if (has("shift")) using.push("shift down");
    if (has("alt") || has("opt")) using.push("option down");
    const usingClause = using.length ? ` using {${using.join(", ")}}` : "";
    return { cmd: ["osascript", "-e", `tell application "System Events" to keystroke "${base}"${usingClause}`] };
  }
  if (os === "linux") {
    const x = chord.replace(/cmd/g, "super");
    return { cmd: ["xdotool", "key", x] };
  }
  if (os === "windows") {
    // SendKeys: ^=ctrl %=alt +=shift; cmd -> ctrl
    let sk = base;
    if (has("cmd") || has("ctrl")) sk = "^" + sk;
    if (has("alt")) sk = "%" + sk;
    if (has("shift")) sk = "+" + sk;
    return { cmd: ["powershell", "-NoProfile", "-Command",
      `Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('${sk}')`] };
  }
  throw new Error(`key unsupported on ${os}`);
}
