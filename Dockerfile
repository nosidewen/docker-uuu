# Dockerized UUU (mfgtools 3.0) from NXP
# https://github.com/NXPmicro/mfgtools
#
# Dockerfile and GH Action based on docker-7zip
# https://github.com/crazy-max/docker-7zip
FROM --platform=${TARGETPLATFORM:-linux/amd64} ubuntu:18.04

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN printf "I am running on ${BUILDPLATFORM:-linux/amd64}, building for ${TARGETPLATFORM:-linux/amd64}\n$(uname -a)\n"

LABEL maintainer="nosidewen" \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.url="https://github.com/nosidewen/docker-uuu" \
  org.opencontainers.image.source="https://github.com/nosidewen/docker-uuu" \
  org.opencontainers.image.version=$VERSION \
  org.opencontainers.image.revision=$VCS_REF \
  org.opencontainers.image.vendor="nosidewen" \
  org.opencontainers.image.title="UUU" \
  org.opencontainers.image.description="UUU" \
  org.opencontainers.image.licenses="BSD-3-Clause"

# packages required for Linux to download, build, and run NXP mfgtools
# https://github.com/NXPmicro/mfgtools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    libusb-1.0-0-dev \
    libzip-dev \
    libbz2-dev \
    pkg-config \
    libssl-dev

# Install CMake 3.13.5
RUN wget "https://cmake.org/files/v3.13/cmake-3.13.5-Linux-x86_64.sh" \
&& chmod a+x cmake-3.13.5-Linux-x86_64.sh \
&& ./cmake-3.13.5-Linux-x86_64.sh --prefix=/usr/local/ --skip-license \
&& rm cmake-3.13.5-Linux-x86_64.sh

WORKDIR  /docker-uuu/mfgtools

# Download latest mfgtools release .tar.gz and build it
#  Using only curl - ask GitHub API for the latest release .tar.gz, then 
#  construct the download URL, then download the release, then extract the 
#  release, then build it.
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#add-or-copy
# https://gist.github.com/steinwaywhw/a4cd19cda655b8249d908261a62687f8#gistcomment-3199552
RUN if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then URL="https://api.github.com/repos/NXPMicro/mfgtools/releases/latest"; else URL="https://api.github.com/repos/NXPMicro/mfgtools/releases/tags/$VERSION"; fi \
    && echo $URL \
    && curl -s "$URL" \
    # grep for line that starts 'browser_download_url' and ends 'tar.gz'
    | grep 'browser_download_url.*tar.gz"' \
    # cut string based on ':' and take fields 2,3
    # (keep "https://github.com/blah" while leave out "browser_download_url:")
    | cut -d : -f 2,3 \
    # trim off quotes
    | tr -d \" \
    # download the .tar.gz
    | xargs -n 1 curl -sSL \
    # uncompress it
    | tar -xz --strip-components=1 \
    # build it
    && cmake . \
    && make

# add mfgtools/uuu to PATH
ENV PATH="/docker-uuu/mfgtools/uuu:${PATH}"

CMD [ "uuu", "-h" ]