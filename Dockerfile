FROM debian:bullseye

RUN apt update && apt upgrade -y && apt install -y curl unzip

