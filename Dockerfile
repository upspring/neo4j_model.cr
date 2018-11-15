### Docker image for neo4j_model.cr testing ###

# See https://github.com/phusion/baseimage-docker/releases for a list of releases.
FROM phusion/baseimage:0.11
LABEL maintainer="aaronn@upspringmedia.com"

# Set up 3rd party repos
RUN curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add -
RUN echo "deb https://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list

# Update packages
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confnew"

# Install other packages we depend on
RUN apt-get install -y tzdata   # base packages: most setups need these
RUN apt-get install -y bzip2 git wget unzip zip  # cmd line utilities
RUN apt-get install -y libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev  # crystal deps

RUN apt-get autoremove -y

WORKDIR /tmp

# Pick a Crystal version and install the .deb: https://github.com/crystal-lang/crystal/releases
RUN curl -sL https://github.com/crystal-lang/crystal/releases/download/0.27.0/crystal_0.27.0-1_amd64.deb > crystal.deb
# RUN curl -sL https://github.com/crystal-lang/crystal/releases/download/0.26.1/crystal_0.26.1-1_amd64.deb > crystal.deb
RUN apt-get install -y ./crystal.deb

# Build guardian
RUN git clone https://github.com/f/guardian.git && cd guardian && crystal build src/guardian.cr --release && cp guardian /usr/bin/

#
# Try to put things AFTER the apt/composer steps so we don't have to redo them as often
#

# Add app user
RUN useradd -m -k /etc/skel app
WORKDIR /home/app/myapp

# Post-build clean up
RUN apt-get clean && rm -rf /tmp/* /var/tmp/*
# RUN rm -rf /var/lib/apt/lists/*

# Run this to start all services (if no command was provided to `docker run`)
CMD ["/sbin/my_init"]
