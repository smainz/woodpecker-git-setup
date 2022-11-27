FROM alpine:3.17

RUN apk add bash git && \
    mkdir -p /woodpecker/src

COPY plugin.sh /bin/plugin.sh
RUN chmod 755 /bin/plugin.sh

WORKDIR /woodpecker/src

CMD  [ "/bin/plugin.sh" ]
