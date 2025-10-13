FROM alpine:3.18

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
    && apk add --no-cache \
    rsync \
    inotify-tools \
    bash \
    tzdata \
    nfs-utils \
    procps \
    && rm -rf /var/cache/apk/*

RUN mkdir -p /data /scripts /var/log

ENV TZ=Asia/Shanghai

COPY inotify-sync.sh /scripts/inotify-sync.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /scripts/inotify-sync.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
