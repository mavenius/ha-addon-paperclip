FROM ghcr.io/paperclipai/paperclip:latest

# NOT overriding HOME here (deliberately) -- leaving it at the upstream
# image's own default (/paperclip, unpersisted). Pointing it at
# /data/paperclip (so `claude login` credentials would survive restarts)
# caused Claude Code to report "not logged in" specifically when invoked by
# Paperclip's own server process, despite every manual reproduction
# succeeding -- confirmed by reverting this override, which fixed it.
# /paperclip itself isn't persisted, but run.sh shadows Claude's login state
# into a backup dir under $PAPERCLIP_HOME (which is) and restores it on
# boot, so `claude login` survives add-on updates without HOME needing to
# move. See DOCS.md.

# These are static (don't depend on the add-on's options.json) so bake them
# in at the image level too, not just as run.sh exports. run.sh's exports
# only apply to the process tree it spawns (the real server, PID 1) -- a
# fresh `docker exec` session is a separate process that only inherits the
# image's baked-in ENV, not another process's shell-local exports. Without
# this, `docker exec ... pnpm paperclipai <cmd>` silently operates against
# the upstream image's unpersisted /paperclip default instead of /data.
ENV PAPERCLIP_HOME=/data/paperclip
ENV PAPERCLIP_INSTANCE_ID=default
ENV PAPERCLIP_CONFIG=/data/paperclip/instances/default/config.json
ENV PAPERCLIP_DEPLOYMENT_MODE=authenticated
ENV PAPERCLIP_DEPLOYMENT_EXPOSURE=private
ENV HOST=0.0.0.0
ENV PORT=3100
ENV SERVE_UI=true

# ttyd: web terminal behind Home Assistant ingress, for the interactive
# `claude auth login` flow (see claude_login.sh). Not packaged for Debian
# trixie (the upstream image's base), so install the project's official
# static release binary, pinned and checksum-verified.
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256_AMD64=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
ARG TTYD_SHA256_ARM64=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) ttydArch="x86_64"; sha256="$TTYD_SHA256_AMD64" ;; \
      arm64) ttydArch="aarch64"; sha256="$TTYD_SHA256_ARM64" ;; \
      *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttydArch}"; \
    echo "${sha256}  /usr/local/bin/ttyd" | sha256sum -c -; \
    chmod a+x /usr/local/bin/ttyd; \
    ttyd --version

COPY run.sh /run.sh
COPY telegram_poll.sh /telegram_poll.sh
COPY telegram_notify.sh /telegram_notify.sh
COPY claude_backup.sh /claude_backup.sh
COPY claude_login.sh /claude_login.sh
RUN chmod a+x /run.sh /telegram_poll.sh /telegram_notify.sh \
  /claude_backup.sh /claude_login.sh

ENTRYPOINT ["/run.sh"]
