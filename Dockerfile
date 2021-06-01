FROM ruby:2.7-slim-buster

RUN echo "deb http://deb.debian.org/debian/ unstable main contrib non-free" >> /etc/apt/sources.list && \
  apt update && \
  apt install --no-install-recommends curl firefox make gcc g++ -y

RUN BASE_URL=https://github.com/mozilla/geckodriver/releases/download \
  && VERSION=$(curl -sL \
    https://api.github.com/repos/mozilla/geckodriver/releases/latest | \
    grep tag_name | cut -d '"' -f 4) \
  && curl -sL "$BASE_URL/$VERSION/geckodriver-$VERSION-linux64.tar.gz" | \
    tar -xz -C /usr/local/bin

COPY ./* /scripts/

WORKDIR /scripts

RUN echo "gem: --no-rdoc --no-ri" >> ~/.gemrc && \
  bundler install --no-cache --jobs 3

RUN apt-get clean autoclean && \
    apt-get autoremove --yes make gcc g++