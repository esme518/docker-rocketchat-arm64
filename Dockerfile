FROM node:20-bookworm-slim

ARG ARCH=aarch64

ENV DENO_VERSION=1.46.3

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NOWARNINGS=yes

RUN set -ex \
  && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL https://dl.deno.land/release/v${DENO_VERSION}/deno-${ARCH}-unknown-linux-gnu.zip --output /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && echo "acf7e0110e186fc515a1b7367d9c56a9f0205ad448c1c08ab769b8e3ce6f700f /tmp/deno-aarch64-unknown-linux-gnu.zip" | sha256sum -c - \
  && unzip /tmp/deno-${ARCH}-unknown-linux-gnu.zip -d /tmp \
  && rm /tmp/deno-${ARCH}-unknown-linux-gnu.zip \
  && chmod 755 /tmp/deno \
  && mv /tmp/deno /usr/local/bin/deno \
  && apt-mark auto '.*' > /dev/null \
  && find /usr/local -type f -executable -exec ldd '{}' ';' \
  | awk '/=>/ { print $(NF-1) }' \
  | sort -u \
  | xargs -r dpkg-query --search \
  | cut -d: -f1 \
  | sort -u \
  | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

RUN groupadd -r rocketchat \
  && useradd -r -g rocketchat rocketchat \
  && mkdir -p /app/uploads \
  && chown rocketchat:rocketchat /app/uploads

VOLUME /app/uploads

WORKDIR /app

ENV NODE_ENV=production

ENV RC_VERSION=7.0.3

RUN set -eux \
  && apt-get update \
  && apt-get install -y --no-install-recommends fontconfig \
  && aptMark="$(apt-mark showmanual)" \
  && apt-get install -y --no-install-recommends g++ make python3 ca-certificates curl gnupg \
  && rm -rf /var/lib/apt/lists/* \
  # gpg: key 4FD08104: public key "Rocket.Chat Buildmaster <buildmaster@rocket.chat>" imported
  && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 0E163286C20D07B9787EBE9FD7F9D0414FD08104 \
  && curl -fSL "https://releases.rocket.chat/${RC_VERSION}/download" -o rocket.chat.tgz \
  && curl -fSL "https://releases.rocket.chat/${RC_VERSION}/asc" -o rocket.chat.tgz.asc \
  && gpg --batch --verify rocket.chat.tgz.asc rocket.chat.tgz \
  && tar zxf rocket.chat.tgz \
  && rm rocket.chat.tgz rocket.chat.tgz.asc \
  && cd bundle/programs/server \
  && npm install --unsafe-perm=true \
  && rm -rf npm/node_modules/sharp \
  && npm install --cpu=arm64 --os=linux sharp@0.32.6 \
  && mv node_modules/sharp npm/node_modules/sharp \
  && apt-mark auto '.*' > /dev/null \
  && apt-mark manual $aptMark > /dev/null \
  && find /usr/local -type f -executable -exec ldd '{}' ';' \
  | awk '/=>/ { print $(NF-1) }' \
  | sort -u \
  | xargs -r dpkg-query --search \
  | cut -d: -f1 \
  | sort -u \
  | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && npm cache clear --force \
  && chown -R rocketchat:rocketchat /app

USER rocketchat

WORKDIR /app/bundle

# needs a mongoinstance - defaults to container linking with alias 'db'
ENV DEPLOY_METHOD=docker-official \
  MONGO_URL=mongodb://db:27017/meteor \
  HOME=/tmp \
  PORT=3000 \
  ROOT_URL=http://localhost:3000

EXPOSE 3000

CMD ["node", "main.js"]
