FROM ghcr.io/paperclipai/paperclip:latest

# Override the upstream image's unpersisted /paperclip home so anything that
# writes there directly via $HOME (claude login credentials, git config, ssh
# known_hosts, etc.) lands under Supervisor's persisted /data instead. This
# applies container-wide, including `docker exec` sessions, not just the
# process our entrypoint launches.
ENV HOME=/data/paperclip

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT ["/run.sh"]
