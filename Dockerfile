FROM ubuntu:22.04 AS fetcher
ENV NVM_VERSION=v0.40.3
RUN apt-get update && \
    apt-get install -y git && \
    git clone \
        --depth 1 \
        --branch $NVM_VERSION \
        https://github.com/nvm-sh/nvm.git

FROM jenkins/inbound-agent:alpine AS jnlp

FROM jenkins/agent:latest-jdk17

ARG version
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$version"

ARG user=jenkins

USER root

COPY --from=jnlp /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-agent

RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

# we don't want to store cached files in the image
VOLUME /var/cache/apt

RUN apt-get update \
  && apt-get -y install \
    unzip \
    curl \
    rsync \
    openssh-client \
    ca-certificates-java \
    openjdk-17-jdk \
    graphviz \
    ca-certificates \
    gnupg

#ENV CHROME_BIN=/usr/bin/chromium-browser
RUN apt-get update && apt-get -y install chromium chromium-driver
RUN apt-get -y install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libnss3 libxss1 libasound2 libxtst6 xauth xvfb
# prepare place for binaries symlinks
RUN mkdir -p /home/jenkins/bin && \
    chown -R jenkins:jenkins /home/jenkins/bin
ENV PATH="$PATH:/home/jenkins/bin"

ENV NVM_DIR=/opt/nvm
# don't store npm cache in the image
VOLUME ~/.npm

# copy the nvm
COPY --from=fetcher --chown=jenkins:jenkins nvm $NVM_DIR
# copy wrapper scripts
COPY bin /usr/local/bin

USER ${user}

RUN nvm install node

RUN curl -fsSL https://get.pnpm.io/install.sh |ENV="$HOME/.shrc" SHELL="$(which sh)" sh -
ENV PNPM_HOME="/home/jenkins/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN pnpm config set store-dir /home/jenkins/.local/share/pnpm/store

# Cypress 13.6.3 because of bugs >13.6.3 https://github.com/cypress-io/cypress/issues/27501
RUN CYPRESS_INSTALL_BINARY=13.6.3 pnpm install -g cypress@13.6.3

USER root

RUN pnpm add -g playwright
RUN playwright install --with-deps chromium

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
