FROM alpine:3.11

COPY LICENSE README.md /

RUN apk --no-cache add bash lftp sshpass git

COPY entrypoint.sh /entrypoint.sh

# Adicionar permissões de execução ao entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]