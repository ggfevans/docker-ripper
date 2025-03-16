FROM phusion/baseimage:noble-1.0.0
LABEL maintainer="rix1337"

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    HOME=/root

# Notification system environment variables:
# NOTIFY_ENABLED=true|false - Enable/disable notification system
# NOTIFY_PROVIDER=discord|pushover|webhook - Select notification provider
# NOTIFY_DISCORD_WEBHOOK_URL - Discord webhook URL (required for Discord)
# NOTIFY_PUSHOVER_API_TOKEN - Pushover API token (required for Pushover)
# NOTIFY_PUSHOVER_USER_KEY - Pushover user key (required for Pushover)
# NOTIFY_WEBHOOK_URL - Generic webhook URL (required for webhook provider)
# NOTIFY_WEBHOOK_METHOD - HTTP method for webhook (default: POST)
# NOTIFY_WEBHOOK_HEADERS - Custom HTTP headers for webhook (JSON format)

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Invalidate build cache on new releases of MakeMKV
ADD "https://launchpad.net/~heyarje/+archive/ubuntu/makemkv-beta/+builds?build_text=makemkv-bin&build_state=built" /dev/null

# Install software
RUN add-apt-repository -y ppa:heyarje/makemkv-beta && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      abcde \
      ccextractor \
      eject \
      eyed3 \
      flac \
      gddrescue \
      glyrc \
      git \
      id3 \
      id3v2 \
      lame \
      makemkv-bin \
      makemkv-oss \
      mkcue \
      python3 \
      python3-docopt \
      python3-flask \
      python3-waitress \
      sdparm \
      speex \
      vorbis-tools \
      vorbisgain \
      wget && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Ensure HOME is available for MakeMKV
RUN echo /root > /etc/container_environment/HOME

# Move Files and set permissions
COPY root/ /
RUN chmod +x /etc/my_init.d/*.sh