# build
FROM elixir:1.18-alpine AS builder

ENV MIX_ENV=prod

WORKDIR /app

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache nodejs npm git build-base bash
RUN mix local.rebar --force && \
    mix local.hex --force

COPY mix.* ./
RUN mix deps.get --only ${MIX_ENV}

COPY . .
RUN ./mix_release.sh

# deployment
FROM alpine:3

ENV MIX_ENV=prod

# UI ports
EXPOSE 4000
EXPOSE 44000
# EPMD Port (needs to be defined as ERL_EPMD_PORT at run-time
# (if accessing from other machines is desired)
EXPOSE 44369
# Distribution port
EXPOSE 49000
# UDP Gossip Port
EXPOSE 45892/udp

# install runtime dependencies
RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add libcrypto3 libgcc libstdc++ ncurses-libs

WORKDIR /app

COPY --from=builder /app/_build/${MIX_ENV}/rel/global_service .

RUN adduser -D app && \
    chown -R app: /app && \
    ls -rtl /app/bin

USER app

ENTRYPOINT ["/app/bin/global_service"]
CMD ["start"]
