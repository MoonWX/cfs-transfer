FROM alpine:3.18

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
    && apk add --no-cache \
    rsync \
    bash \
    tzdata \
    nfs-utils \
    gettext \
    jq \
    && rm -rf /var/cache/apk/*

RUN mkdir -p /data /var/log /var/run /etc/rsync

ENV TZ=Asia/Shanghai

COPY rsyncd.conf.template /etc/rsync/rsyncd.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 873

ENTRYPOINT ["/entrypoint.sh"]
