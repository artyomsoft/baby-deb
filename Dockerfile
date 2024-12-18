FROM debian:12

ARG OUTPUT_DIR="/output"

ENV CONTAINER="docker"
ENV OUTPUT_DIR=${OUTPUT_DIR}

RUN mkdir /app /output

WORKDIR /app

RUN apt update && apt install -y debootstrap fdisk dosfstools kpartx

COPY build-linux-image.sh /app

ENTRYPOINT ["/bin/bash", "-c", "./build-linux-image.sh \"$@\"", "--"]

