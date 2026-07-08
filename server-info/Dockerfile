FROM nginx:1.27-alpine

# дефолтные значения переменных (переопределяются через ConfigMap/env в Deployment)
ENV APP_NAME="server-info" \
    APP_VERSION="1.0.0" \
    APP_ENV="production"

# статическая страница
COPY app/index.html /usr/share/nginx/html/index.html

# шаблон конфига: официальный entrypoint-скрипт nginx автоматически
# прогонит его через envsubst и положит в /etc/nginx/conf.d/default.conf
COPY app/default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1/healthz || exit 1
