FROM nginxinc/nginx-unprivileged:alpine
# La base trae paquetes con CVEs críticas ya parcheadas: actualizar en el build
USER root
RUN apk upgrade --no-cache
USER 101
COPY index.html /usr/share/nginx/html/index.html
