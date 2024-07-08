FROM alpine:3.11

COPY LICENSE README.md /

RUN apk --no-cache add lftp sshpass

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]