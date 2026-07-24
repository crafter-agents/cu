#!/usr/bin/env bash
# cu — cross-platform computer-use CLI. One agnostic verb, the right OS primitive.
# Usage:  cu <action> [args]
# Actions: capture <file> | launch <app> | type <text> | key <chord> |
#          move <x> <y> | click [x y] | scroll | diff <a> <b> | record <prefix> [n] [iv] | read-text | os
# The agent writes `cu type "hi"`; cu picks osascript / SendKeys / xdotool by OS.
# Built by Kai. Action vocabulary follows agent-browser's native interaction set.
set -uo pipefail

# --- OS detection (agnostic core) --------------------------------------------
cu_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) [ -n "${OS:-}" ] && echo "windows" || echo "unknown" ;;
  esac
}
OS="$(cu_os)"
: "${CU_DISPLAY:=:99}"   # linux xvfb display

die() { echo "cu: $*" >&2; exit 1; }

# --- Linux helper: ensure a display exists -----------------------------------
cu_linux_display() {
  export DISPLAY="$CU_DISPLAY"
  command -v Xvfb    >/dev/null || sudo apt-get install -y xvfb        >/dev/null 2>&1
  command -v xdotool >/dev/null || sudo apt-get install -y xdotool     >/dev/null 2>&1
  command -v import  >/dev/null || sudo apt-get install -y imagemagick >/dev/null 2>&1
  command -v xdpyinfo>/dev/null || sudo apt-get install -y x11-utils   >/dev/null 2>&1
  if ! DISPLAY="$CU_DISPLAY" xdpyinfo >/dev/null 2>&1; then
    Xvfb "$CU_DISPLAY" -screen 0 1280x1024x24 >/dev/null 2>&1 &
    for _ in $(seq 1 20); do DISPLAY="$CU_DISPLAY" xdpyinfo >/dev/null 2>&1 && break; sleep 0.5; done
  fi
}

# --- actions -----------------------------------------------------------------
action="${1:-}"; shift || true
case "$action" in
  os) echo "$OS" ;;

  capture)
    out="${1:?cu capture <file>}"
    case "$OS" in
      macos)   screencapture -x "$out" ;;
      linux)   cu_linux_display; import -window root "$out" ;;
      windows) powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms,System.Drawing; \$v=[System.Windows.Forms.SystemInformation]::VirtualScreen; \$b=New-Object System.Drawing.Bitmap(\$v.Width,\$v.Height); [System.Drawing.Graphics]::FromImage(\$b).CopyFromScreen(\$v.Left,\$v.Top,0,0,\$b.Size); \$b.Save('$out')" ;;
      *) die "capture unsupported on $OS" ;;
    esac
    [ -f "$out" ] && echo "captured $out ($(wc -c <"$out" | tr -d ' ')B)" || die "capture failed"
    ;;

  launch)
    app="${1:?cu launch <app>}"
    case "$OS" in
      macos)   osascript -e "tell application \"$app\" to activate" ;;
      linux)   cu_linux_display; ( "$app" >/dev/null 2>&1 & ) ; sleep 1 ;;
      windows) powershell -NoProfile -Command "Start-Process '$app'" ;;
      *) die "launch unsupported on $OS" ;;
    esac
    echo "launched $app on $OS"
    ;;

  type)
    text="${1:?cu type <text>}"
    case "$OS" in
      macos)   osascript -e "tell application \"System Events\" to keystroke \"$text\"" ;;
      linux)   cu_linux_display; xdotool type -- "$text" ;;
      windows) powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('$text')" ;;
      *) die "type unsupported on $OS" ;;
    esac
    echo "typed on $OS"
    ;;

  key)
    chord="${1:?cu key <chord>}"   # e.g. cmd+a, ctrl+c
    case "$OS" in
      macos)
        # map chord -> osascript "using ... down"
        base="${chord##*+}"; mods="${chord%+*}"
        using=""
        case "$mods" in *cmd*|*meta*) using="$using command down,";; esac
        case "$mods" in *ctrl*) using="$using control down,";; esac
        case "$mods" in *shift*) using="$using shift down,";; esac
        case "$mods" in *alt*|*opt*) using="$using option down,";; esac
        using="{${using%,}}"
        osascript -e "tell application \"System Events\" to keystroke \"$base\" using $using" ;;
      linux)   cu_linux_display; xdotool key "$(echo "$chord" | sed 's/cmd/super/; s/+/+/g')" ;;
      windows)
        # SendKeys: ^=ctrl %=alt +=shift  (cmd->ctrl)
        sk="$chord"; sk="${sk//cmd+/^}"; sk="${sk//ctrl+/^}"; sk="${sk//alt+/%}"; sk="${sk//shift+/+}"
        powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('$sk')" ;;
      *) die "key unsupported on $OS" ;;
    esac
    echo "sent $chord on $OS"
    ;;

  move)
    x="${1:?cu move <x> <y>}"; y="${2:?cu move <x> <y>}"
    case "$OS" in
      macos)   osascript -e "tell application \"System Events\" to set mouseLoc to {$x, $y}" 2>/dev/null || cliclick "m:$x,$y" 2>/dev/null || die "install cliclick for mouse on macOS" ;;
      linux)   cu_linux_display; xdotool mousemove "$x" "$y" ;;
      windows) powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point($x,$y)" ;;
      *) die "move unsupported on $OS" ;;
    esac
    echo "moved to $x,$y on $OS"
    ;;

  click)
    # cu click [x y]  -- click at coords, or current position if omitted
    x="${1:-}"; y="${2:-}"
    case "$OS" in
      macos)   [ -n "$x" ] && osascript -e "tell application \"System Events\" to click at {$x, $y}" 2>/dev/null || cliclick "c:${x:-.},${y:-.}" 2>/dev/null || die "install cliclick for click on macOS" ;;
      linux)   cu_linux_display; [ -n "$x" ] && xdotool mousemove "$x" "$y"; xdotool click 1 ;;
      windows) powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; if('$x'){[System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point($x,$y)}; Add-Type 'using System;using System.Runtime.InteropServices;public class M{[DllImport(\"user32.dll\")]public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);}'; [M]::mouse_event(2,0,0,0,0);[M]::mouse_event(4,0,0,0,0)" ;;
      *) die "click unsupported on $OS" ;;
    esac
    echo "clicked${x:+ at $x,$y} on $OS"
    ;;

  dblclick)
    x="${1:-}"; y="${2:-}"
    "$0" click ${x:+$x $y} >/dev/null; "$0" click ${x:+$x $y} >/dev/null
    echo "double-clicked${x:+ at $x,$y} on $OS"
    ;;

  scroll)
    dir="${1:-down}"; amt="${2:-5}"
    case "$OS" in
      macos)   code=$([ "$dir" = up ] && echo 116 || echo 121); for _ in $(seq 1 "$amt"); do osascript -e "tell application \"System Events\" to key code $code" 2>/dev/null || die "scroll needs accessibility"; done ;;
      linux)   cu_linux_display; b=$([ "$dir" = up ] && echo 4 || echo 5); for _ in $(seq 1 "$amt"); do xdotool click "$b"; done ;;
      windows) powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{PGDN}')" ;;
      *) die "scroll unsupported on $OS" ;;
    esac
    echo "scrolled $dir $amt on $OS"
    ;;

  select-all)  "$0" key "$([ "$OS" = macos ] && echo cmd+a || echo ctrl+a)" ;;
  copy)        "$0" key "$([ "$OS" = macos ] && echo cmd+c || echo ctrl+c)" ;;
  paste)       "$0" key "$([ "$OS" = macos ] && echo cmd+v || echo ctrl+v)" ;;

  diff)
    a="${1:?cu diff <a.png> <b.png>}"; b="${2:?cu diff <a.png> <b.png>}"
    [ -f "$a" ] && [ -f "$b" ] || die "diff: both files must exist"
    # self-sufficient: install Pillow if python3 exists but PIL does not
    if command -v python3 >/dev/null 2>&1 && ! python3 -c "import PIL" 2>/dev/null; then
      python3 -m pip install --quiet Pillow >/dev/null 2>&1 || true
    fi
    if command -v python3 >/dev/null 2>&1 && python3 -c "import PIL" 2>/dev/null; then
      python3 -c "import sys; from PIL import Image, ImageChops; a=Image.open(sys.argv[1]).convert('RGB'); b=Image.open(sys.argv[2]).convert('RGB'); b=b if a.size==b.size else b.resize(a.size); d=ImageChops.difference(a,b); ch=sum(1 for p in d.getdata() if p[0]+p[1]+p[2]>30); tot=a.size[0]*a.size[1]; pct=round(100*ch/tot,2); print('changed %s%%' % pct); print('SAME' if pct<1 else 'CHANGED')" "$a" "$b"
    elif command -v compare >/dev/null 2>&1; then
      n=$(compare -metric AE "$a" "$b" null: 2>&1 | tr -cd '0-9' )
      echo "changed-pixels ${n:-0}"
      [ "${n:-0}" -lt 500 ] && echo "SAME" || echo "CHANGED"
    else
      # last-resort fallback: compare file byte sizes (crude but never errors out)
      sa=$(wc -c <"$a" | tr -d " "); sb=$(wc -c <"$b" | tr -d " ")
      big=$sa; sml=$sb; [ "$sb" -gt "$sa" ] && big=$sb && sml=$sa
      d=$(( (big - sml) * 100 / (big>0?big:1) ))
      echo "changed ~${d}% (byte-size fallback, no PIL/ImageMagick)"
      [ "$d" -lt 2 ] && echo "SAME" || echo "CHANGED"
    fi
    ;;

  record)
    # cu record <prefix> [count] [interval_s] -- N sequential captures
    prefix="${1:?cu record <prefix> [count] [interval]}"; n="${2:-5}"; iv="${3:-1}"
    i=0
    while [ "$i" -lt "$n" ]; do
      "$0" capture "${prefix}-$(printf %03d "$i").png" >/dev/null 2>&1 || die "record: capture $i failed"
      i=$((i+1)); [ "$i" -lt "$n" ] && sleep "$iv"
    done
    echo "recorded $n frames to ${prefix}-NNN.png on $OS"
    ;;

  read-text)
    case "$OS" in
      macos)   osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null ;;
      *) die "read-text is macOS-only for now" ;;
    esac
    ;;

  ""|-h|--help|help)
    grep '^# ' "$0" | sed 's/^# //'
    ;;
  *) die "unknown action '$action' (try: cu help)" ;;
esac
