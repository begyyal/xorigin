FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

ARG apts=""
RUN apt-get update
RUN apt-get -y install nodejs npm $apts

WORKDIR /cmdbbt
COPY /app .

RUN npm install
RUN npm run build

ENTRYPOINT nodejs -r source-map-support/register /cmdbbt
