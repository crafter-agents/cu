// Pure command builders: each action -> the exact argv per OS. No side effects,
// so every mapping is unit-testable without touching the machine.
import type { OS } from "./os.ts";

const ps = (script: string) => ["powershell", "-NoProfile", "-Command", script];

export function captureCmd(os: OS, out: string): string[] {
  switch (os) {
    case "macos": return ["screencapture", "-x", out];
    case "linux": return ["import", "-window", "root", out];
    case "windows": return ps(
      `Add-Type -AssemblyName System.Windows.Forms,System.Drawing;` +
      `$v=[System.Windows.Forms.SystemInformation]::VirtualScreen;` +
      `$b=New-Object System.Drawing.Bitmap($v.Width,$v.Height);` +
      `[System.Drawing.Graphics]::FromImage($b).CopyFromScreen($v.Left,$v.Top,0,0,$b.Size);` +
      `$b.Save('${out}')`);
    default: throw new Error(`capture unsupported on ${os}`);
  }
}

export function typeCmd(os: OS, text: string): string[] {
  switch (os) {
    case "macos": return ["osascript", "-e", `tell application "System Events" to keystroke "${text}"`];
    case "linux": return ["xdotool", "type", "--", text];
    case "windows": return ps(`Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('${text}')`);
    default: throw new Error(`type unsupported on ${os}`);
  }
}

export function launchCmd(os: OS, app: string): string[] {
  switch (os) {
    case "macos": return ["osascript", "-e", `tell application "${app}" to activate`];
    case "linux": return ["sh", "-c", `("${app}" >/dev/null 2>&1 &)`];
    case "windows": return ps(`Start-Process '${app}'`);
    default: throw new Error(`launch unsupported on ${os}`);
  }
}

export function moveCmd(os: OS, x: number, y: number): string[] {
  switch (os) {
    case "macos": return ["osascript", "-e", `tell application "System Events" to set the position of the mouse to {${x}, ${y}}`];
    case "linux": return ["xdotool", "mousemove", String(x), String(y)];
    case "windows": return ps(`Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point(${x},${y})`);
    default: throw new Error(`move unsupported on ${os}`);
  }
}

export function scrollCmd(os: OS, dir: "up" | "down", amount: number): string[][] {
  switch (os) {
    case "macos": {
      const code = dir === "up" ? 116 : 121; // PgUp / PgDn
      return Array.from({ length: amount }, () => ["osascript", "-e", `tell application "System Events" to key code ${code}`]);
    }
    case "linux": {
      const b = dir === "up" ? "4" : "5";
      return Array.from({ length: amount }, () => ["xdotool", "click", b]);
    }
    case "windows":
      return Array.from({ length: amount }, () => ps(`Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{${dir === "up" ? "PGUP" : "PGDN"}}')`));
    default: throw new Error(`scroll unsupported on ${os}`);
  }
}

// which key a semantic action maps to (select-all/copy/paste) per OS
export function comboKey(os: OS, action: "select-all" | "copy" | "paste"): string {
  const letter = action === "select-all" ? "a" : action === "copy" ? "c" : "v";
  return os === "macos" ? `cmd+${letter}` : `ctrl+${letter}`;
}
