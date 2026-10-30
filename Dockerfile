# Wraps the official 3x-ui image with an nginx layer so that the panel
# AND an Xray inbound (WS/xhttp) can both be reached through the single
# public port Railway assigns to a service.
# Panel version: latest by default. To pin, set Railway variable XUI_VERSION (e.g. v3.10.0).
ARG XUI_VERSION=latest
FROM ghcr.io/mhsanaei/3x-ui:${XUI_VERSION}

# nginx  -> reverse proxy / path router
# gettext -> provides envsubst, used to inject Railway's $PORT at runtime
RUN apk add --no-cache nginx gettext

COPY default.conf.template /etc/nginx/http.d/default.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Local/default fallback; Railway overrides this with its own $PORT at runtime
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
