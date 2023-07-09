FROM debian:bullseye

ENV LANG C.UTF-8

RUN apt update && apt upgrade -y && apt install -y curl unzip docker docker.io

