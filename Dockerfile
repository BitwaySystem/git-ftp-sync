FROM ubuntu:latest

COPY LICENSE README.md /

RUN apt-get update && \
    apt-get install -y lftp sshpass curl git && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]