FROM alpine:3.5

MAINTAINER Huang Rui <vowstar@gmail.com>, Turtle <turtled@emqtt.io>

ENV EMQ_VERSION=v2.1.0-beta.2

RUN set -ex \
    # add build deps, remove after build
    && apk --no-cache add --virtual .build-deps \
        build-base \
        # gcc \
        # make \
        perl \
        erlang \
        erlang-public-key \
        erlang-syntax-tools \
        erlang-erl-docgen \
        erlang-gs \
        erlang-observer \
        erlang-ssh \
        #erlang-ose \
        erlang-cosfiletransfer \
        erlang-runtime-tools \
        erlang-os-mon \
        erlang-tools \
        erlang-cosproperty \
        erlang-common-test \
        erlang-dialyzer \
        erlang-edoc \
        erlang-otp-mibs \
        erlang-crypto \
        erlang-costransaction \
        erlang-odbc \
        erlang-inets \
        erlang-asn1 \
        erlang-snmp \
        erlang-erts \
        erlang-et \
        erlang-cosnotification \
        erlang-xmerl \
        erlang-typer \
        erlang-coseventdomain \
        erlang-stdlib \
        erlang-diameter \
        erlang-hipe \
        erlang-ic \
        erlang-eunit \
        #erlang-webtool \
        erlang-mnesia \
        erlang-erl-interface \
        #erlang-test-server \
        erlang-sasl \
        erlang-jinterface \
        erlang-kernel \
        erlang-orber \
        erlang-costime \
        erlang-percept \
        erlang-dev \
        erlang-eldap \
        erlang-reltool \
        erlang-debugger \
        erlang-ssl \
        erlang-megaco \
        erlang-parsetools \
        erlang-cosevent \
        erlang-compiler \
    # add fetch deps, remove after build
    && apk add --no-cache --virtual .fetch-deps \
        git \
        wget \
    # add run deps, never remove
    && apk add --no-cache --virtual .run-deps \
        ncurses-terminfo-base \
        ncurses-terminfo \
        ncurses-libs \
        readline \
        curl \
        bind-tools \
    # add latest rebar
    && wget https://github.com/rebar/rebar/wiki/rebar -O /usr/bin/rebar \
    && chmod +x /usr/bin/rebar \
    && git clone -b ${EMQ_VERSION} https://github.com/emqtt/emq-relx.git /emqttd \
    && cd /emqttd \
    && make \
    && mkdir -p /opt && mv /emqttd/_rel/emqttd /opt/emqttd \
    && cd / && rm -rf /emqttd \
    && ln -s /opt/emqttd/bin/* /usr/local/bin/ \
    # remove rebar
    && rm -rf /usr/bin/rebar \
    # removing fetch deps and build deps
    && apk --purge del .build-deps .fetch-deps \
    && rm -rf /var/cache/apk/*

COPY ./start.sh /opt/emqttd/start.sh
RUN chmod +x /opt/emqttd/start.sh
WORKDIR /opt/emqttd

# start emqttd and initial environments
CMD ["/opt/emqttd/start.sh"]

VOLUME ["/opt/emqttd/log", "/opt/emqttd/data", "/opt/emqttd/lib", "/opt/emqttd/etc"]

# emqttd will occupy these port:
# - 1883 port for MQTT
# - 8883 port for MQTT(SSL)
# - 8083 for WebSocket/HTTP
# - 8084 for WSS/HTTPS
# - 18083 for dashboard
# - 4369 for port mapping
# - 6000-6999 for distributed node
EXPOSE 1883 8883 8083 8084 18083 4369 6000-6999
