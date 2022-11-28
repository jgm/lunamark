ARG FROM=ubuntu:latest

FROM $FROM

ARG ROCKSPEC

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qy update \
 && apt-get -qy install --no-install-suggests --no-install-recommends \
    build-essential \
    git \
    luarocks \
    tidy \
 && luarocks install diff \
 && luarocks install luafilesystem

COPY . /opt/lunamark
WORKDIR /opt/lunamark
RUN luarocks make $ROCKSPEC

RUN rm -rf /opt/lunamark \
    apt-qet remove \
    git \
    luarocks \
 && apt-get -qy clean \
 && apt-get -qy autoremove --purge

ENTRYPOINT ["/usr/local/bin/lunamark"]
