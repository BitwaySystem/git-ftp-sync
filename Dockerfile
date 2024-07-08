FROM ubuntu:20.04

COPY LICENSE README.md /

RUN apt-get update && apt-get install -y \
    bash \
    lftp \
    sshpass \
    git \
    curl

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]