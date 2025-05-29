# syntax=docker/dockerfile:1

# global build-time arguments for FROM statements
ARG NODE_VERSION="20"

FROM node:${NODE_VERSION}-bookworm AS builder

# build-time arguments for builder
ARG OPEN5GS_VERSION="v2.7.5"
ARG DEBIAN_FRONTEND="noninteractive"

RUN apt-get clean 
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get upgrade -y

# install dependencies
RUN apt-get update && apt-get install git -y

# clone the specific open5gs version
RUN git clone https://github.com/roastedbeans/5g-network-simulator.git

# install webui
RUN cd 5g-network-simulator && npm ci && npm run build

FROM node:${NODE_VERSION}-bookworm-slim

# copy webui
COPY --from=builder /5g-network-simulator/ /usr/local/src/webui

ENV DB_URI="mongodb://localhost/open5gs"
ENV HOSTNAME="0.0.0.0"
ENV PORT=9998
ENV NODE_ENV="dev"

WORKDIR /usr/local/src/webui
ENTRYPOINT ["npm"]

# use CMD to provide arguments to ENTRYPOINT (can be overridden by user)
CMD [ "run", "dev" ]
