#!/usr/bin/env bash
# The only program the ingress web terminal (ttyd, started by run.sh) runs:
# a small fixed menu around `claude auth`, so opening the add-on's web UI
# from Home Assistant gives you Claude's interactive login and nothing else
# -- no shell, no Claude session. ttyd runs as root so this can refresh the
# persisted backup right after a login; every `claude` call itself drops to
# the node user with HOME=/paperclip, exactly how the Paperclip server
# invokes it (see the Dockerfile comment for why HOME must stay there).

as_node() {
  gosu node env HOME=/paperclip "$@"
}

show_status() {
  echo
  if as_node claude auth status --text; then
    :
  else
    echo "Not logged in."
  fi
  if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo
    echo "Note: anthropic_api_key is set on the Configuration tab. Agents will"
    echo "bill against that API key instead of this login until you clear it."
  fi
  echo
}

save_login() {
  /claude_backup.sh && echo "Login state saved to persistent storage."
}

while true; do
  clear
  echo "=== Paperclip AI: Claude login ==="
  show_status
  echo "  1) Log in with a Claude subscription (Pro/Max)"
  echo "  2) Log in with an Anthropic Console account (API billing)"
  echo "  3) Log out"
  echo "  4) Refresh status"
  echo
  read -r -p "Choose an option: " choice
  echo
  case "$choice" in
    1)
      echo "Open the URL below in your browser, authorize, then paste the code back here."
      echo
      as_node claude auth login
      save_login
      ;;
    2)
      echo "Open the URL below in your browser, authorize, then paste the code back here."
      echo
      as_node claude auth login --console
      save_login
      ;;
    3)
      as_node claude auth logout
      save_login
      ;;
    *)
      continue
      ;;
  esac
  echo
  read -r -p "Press Enter to continue..." _
done
