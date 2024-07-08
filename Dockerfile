FROM alpine:3.11

COPY LICENSE README.md /

RUN apk --no-cache add lftp sshpass

COPY entrypoint.sh /entrypoint.sh

# Adicionar permissões de execução ao entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]