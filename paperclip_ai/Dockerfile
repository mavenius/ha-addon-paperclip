FROM ghcr.io/paperclipai/paperclip:latest

# Override the upstream image's unpersisted /paperclip home so anything that
# writes there directly via $HOME (claude login credentials, git config, ssh
# known_hosts, etc.) lands under Supervisor's persisted /data instead. This
# applies container-wide, including `docker exec` sessions, not just the
# process our entrypoint launches.
ENV HOME=/data/paperclip

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
