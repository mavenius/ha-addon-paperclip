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

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT ["/run.sh"]
