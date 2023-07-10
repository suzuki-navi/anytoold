#FROM debian:bullseye
FROM debian:12.0

ENV LANG C.UTF-8

RUN apt update && apt upgrade -y && apt install -y curl unzip

