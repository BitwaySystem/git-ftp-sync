FROM alpine:3.11

COPY LICENSE README.md /

RUN apk --no-cache add bash lftp sshpass git && \
    ln -sf /bin/bash /bin/sh

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]