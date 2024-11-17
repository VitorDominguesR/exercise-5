FROM ubuntu:24.04
RUN apt update -y
RUN apt upgrade -y && apt install -y openssl cron nano

WORKDIR /root/

COPY --chmod=755 . .

RUN ./setup.sh > log
