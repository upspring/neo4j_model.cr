### Docker image for neo4j_model.cr testing ###

# See https://github.com/phusion/baseimage-docker/releases for a list of releases.
FROM phusion/baseimage:0.11
LABEL maintainer="aaronn@upspringdigital.com"

# Update packages
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confnew"

WORKDIR /tmp

# Pick a Crystal version and install the .deb: https://github.com/crystal-lang/crystal/releases
RUN curl -sL https://github.com/crystal-lang/crystal/releases/download/0.27.2/crystal_0.27.2-1_amd64.deb > crystal.deb
RUN apt-get install -y ./crystal.deb

RUN apt-get install -y libyaml-dev
RUN apt-get autoremove -y

# Build guardian
RUN git clone https://github.com/f/guardian.git && cd guardian && crystal build src/guardian.cr --release && cp guardian /usr/bin/

# Add app user
RUN useradd -m -k /etc/skel app
WORKDIR /home/app/myapp

# Startup scripts
RUN mkdir -p /etc/my_init.d
COPY docker/startup/chown.sh /etc/my_init.d/

# Post-build clean up
RUN apt-get clean && rm -rf /tmp/* /var/tmp/*
RUN rm -rf /var/lib/apt/lists/*

# Run this to start all services (if no command was provided to `docker run`)
CMD ["/sbin/my_init"]
