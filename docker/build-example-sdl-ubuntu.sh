#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd ${SCRIPT_DIR}/..

echo -e "
FROM ubuntu:22.04

RUN apt-get -qq update                    \
    && apt-get install wget libfreetype-dev libfontconfig-dev libcurl4 gcc libsdl2-2.0-0 libgl1 -qq -y --no-install-recommends --no-install-suggests \
    && mkdir -p /tmp/dmd/ && cd /tmp/dmd \
    && wget -q --no-check-certificate https://downloads.dlang.org/releases/2.x/2.106.1/dmd_2.106.1-0_amd64.deb \
    && dpkg -i /tmp/dmd/dmd_2.106.1-0_amd64.deb \
    && rm -rf /tmp/dmd
" | docker build --network=host -t ubuntu-nanogui -

xhost +local:docker

SCALE=1

if [[ ! -z $1 ]];
then 
    SCALE=$1
fi

docker run -it --rm                            \
    -e DISPLAY=$DISPLAY                        \
    -v /tmp/.X11-unix:/tmp/.X11-unix           \
    -v $(pwd):/src                             \
    -v $HOME/.dub/:/root/.dub                  \
    -w /src                                    \
    --network host                             \
    ubuntu-nanogui                             \
    bash -c "cd /src/examples/sdl/ && dub run -- --scale $SCALE"
