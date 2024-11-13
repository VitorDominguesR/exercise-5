FROM ubuntu:22.04
RUN apt update -y
RUN apt upgrade -y && apt install openssl cron nano

WORKDIR /root/

COPY --chmod=755 . .

RUN ./setup.sh > log

# useradd -m -s /bin/bash -g Financial --password $(openssl rand -base64 12) --expiredate 2024-12-06 joao