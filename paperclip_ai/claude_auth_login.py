#!/usr/bin/env python3
"""Run `claude auth login` with a masked code prompt.

Called by claude_login.sh (the ingress login menu). Extra arguments are
passed through to `claude auth login` (e.g. --console).

Claude's own "paste code" prompt shows nothing at all while you paste, so
there's no sign the code arrived. This runs claude in a pseudo-terminal and
passes its output through unchanged. Once the login URL has been printed and
claude has gone quiet (it's now waiting for the code), this shows its own
prompt that masks all but the last few characters, then types the finished
code into claude. claude's output during that prompt is held back and shown
right after, so its redraws don't overwrite the prompt line.
"""

import fcntl
import os
import pty
import re
import select
import signal
import sys
import termios
import time
import tty

CMD = ["gosu", "node", "env", "HOME=/paperclip", "claude", "auth", "login", *sys.argv[1:]]
PROMPT = "Paste the code from your browser, then press Enter: "
KEEP = 4  # trailing characters left unmasked
QUIET_SECONDS = 1.0
URL_RE = re.compile(r"https://\S+")
# Terminal escape sequences: CSI (arrows, colors, bracketed-paste markers),
# OSC (titles, hyperlinks), and two-character escapes.
ESC_RE = re.compile(r"\x1b(\[[0-9;?]*[ -/]*[@-~]|\][^\x07\x1b]*(\x07|\x1b\\)|.)?")


def winsize(fd):
    return fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8)


def main():
    stdin, stdout = sys.stdin.fileno(), sys.stdout.fileno()
    if not os.isatty(stdin):
        os.execvp(CMD[0], CMD)

    pid, master = pty.fork()
    if pid == 0:
        os.execvp(CMD[0], CMD)

    def sync_size(*_):
        try:
            fcntl.ioctl(master, termios.TIOCSWINSZ, winsize(stdin))
        except OSError:
            pass

    sync_size()
    signal.signal(signal.SIGWINCH, sync_size)

    saved = termios.tcgetattr(stdin)
    tty.setraw(stdin)
    try:
        relay(master, stdin, stdout)
    finally:
        termios.tcsetattr(stdin, termios.TCSADRAIN, saved)
    _, status = os.waitpid(pid, 0)
    sys.exit(os.waitstatus_to_exitcode(status))


def render(stdin, stdout, code):
    cols = int.from_bytes(winsize(stdin)[2:4], sys.byteorder) or 80
    shown = "*" * max(len(code) - KEEP, 0) + code[-KEEP:] if code else ""
    count = f"  ({len(code)} characters)" if code else ""
    room = max(cols - len(PROMPT) - len(count) - 1, 8)
    if len(shown) > room:
        shown = "…" + shown[-(room - 1):]
    os.write(stdout, f"\r\x1b[K{PROMPT}{shown}{count}".encode())


def relay(master, stdin, stdout):
    # passthrough: act as a plain terminal until claude is waiting for the code
    # prompting: our masked prompt owns the line; claude's output is held back
    # sent: the code has been typed into claude; plain terminal again
    state = "passthrough"
    seen = ""  # recent claude output, escapes stripped, to spot the URL
    held = b""
    code = ""
    last_output = time.monotonic()

    while True:
        try:
            ready, _, _ = select.select([master, stdin], [], [], 0.2)
        except InterruptedError:
            continue

        if master in ready:
            try:
                data = os.read(master, 4096)
            except OSError:
                data = b""
            if not data:
                break  # claude exited
            last_output = time.monotonic()
            if state == "prompting":
                held += data
            else:
                os.write(stdout, data)
                if state == "passthrough":
                    seen = (seen + ESC_RE.sub("", data.decode(errors="replace")))[-8192:]

        if stdin in ready:
            data = os.read(stdin, 4096)
            if not data:
                break  # browser tab closed
            if state == "passthrough" and URL_RE.search(seen):
                # Already typing into claude's own prompt; don't take over.
                state = "sent"
            if state != "prompting":
                os.write(master, data)
            else:
                for ch in ESC_RE.sub("", data.decode(errors="ignore")):
                    if ch in "\r\n":
                        if code:
                            os.write(stdout, b"\r\n")
                            os.write(master, code.encode())
                            time.sleep(0.3)  # keep Enter separate from the pasted text
                            os.write(master, b"\r")
                            state = "sent"
                            break
                    elif ch in "\x7f\x08":
                        code = code[:-1]
                    elif ch == "\x15":  # Ctrl-U
                        code = ""
                    elif ch == "\x03":  # Ctrl-C: hand it to claude and stop prompting
                        os.write(stdout, b"\r\n")
                        os.write(master, b"\x03")
                        state = "sent"
                        break
                    elif ch.isprintable() and not ch.isspace():
                        code += ch
                if state == "prompting":
                    render(stdin, stdout, code)
                else:
                    os.write(stdout, held)
                    held = b""

        if (
            state == "passthrough"
            and URL_RE.search(seen)
            and time.monotonic() - last_output > QUIET_SECONDS
        ):
            state = "prompting"
            os.write(stdout, b"\r\n\x1b[?25h")  # new line, cursor visible
            render(stdin, stdout, code)

    if state == "prompting":
        os.write(stdout, b"\r\n" + held)


if __name__ == "__main__":
    main()
