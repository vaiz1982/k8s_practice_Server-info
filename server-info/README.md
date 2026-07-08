 sudo docker run --rm -p 8080:80 vaiz82/server-info:1.0.0







# server-info: nginx + SSI + K8s (dev/prod) + ArgoCD

## Структура репозитория

```
server-info/
├── Dockerfile
├── build.sh
├── app/
│   ├── index.html                 # SSI-страница
│   └── default.conf.template      # шаблон nginx-конфига (envsubst + SSI on)
├── base/                          # общие манифесты (kustomize base)
│   ├── kustomization.yaml         # + configMapGenerator (базовые APP_* значения)
│   ├── deployment.yaml            # Deployment (replicas переопределяется в overlay) + Service
│   └── ingress.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml     # namespace: dev, APP_ENV=development, replicas=1, host=dev.server-info.local
│   └── prod/
│       └── kustomization.yaml     # namespace: prod, APP_ENV=production, replicas=3, host=server-info.local
└── argocd/
    ├── app-dev.yaml                # ArgoCD Application -> overlays/dev -> namespace dev
    └── app-prod.yaml               # ArgoCD Application -> overlays/prod -> namespace prod
```

Два namespace = два окружения одного приложения (`dev` и `prod`). Компонентное
разделение (например, отдельный namespace под ingress/инфраструктуру) — сделаем
отдельным шагом позже.

## 1. Сборка образа

Не изменилось:
```bash
cd server-info
docker build -t <your-registry>/server-info:1.0.0 .
docker push <your-registry>/server-info:1.0.0
```
Замените `image:` в `base/deployment.yaml` на свой образ (он общий для обоих overlays).

## 2. Namespaces + ConfigMap + Deployment (kustomize)

Создать namespaces (или доверить это ArgoCD через `CreateNamespace=true`, см. ниже):
```bash
kubectl create namespace dev
kubectl create namespace prod
```

Локальная проверка сборки без применения:
```bash
kubectl kustomize overlays/dev
kubectl kustomize overlays/prod
```

Применить руками (без ArgoCD, для теста):
```bash
kubectl apply -k overlays/dev
kubectl apply -k overlays/prod

kubectl get pods -n dev  -l app=server-info
kubectl get pods -n prod -l app=server-info
```

Что делает kustomize:
- `base/kustomization.yaml` объявляет `configMapGenerator` с базовыми
  `APP_NAME/APP_VERSION/APP_ENV` — сама ConfigMap не хранится статическим YAML,
  а генерируется (с хэшем в имени, что даёт автоматический rollout Deployment'а
  при изменении значений).
- Каждый overlay (`dev`, `prod`) задаёт `namespace:` и через
  `configMapGenerator.behavior: merge` переопределяет `APP_ENV`, а через JSON-патчи —
  число реплик и `host` в Ingress.
- `deployment.yaml` ссылается на ConfigMap по логическому имени
  `server-info-config` — kustomize сам подставит сгенерированное (с хэшем) имя.

## 3. Ingress

Ingress-контроллер общий на кластер, ставится один раз:
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

После `kubectl apply -k overlays/<env>` в каждом namespace появится свой
Ingress с отдельным host:
- dev:  `dev.server-info.local`
- prod: `server-info.local`

Для локальной проверки пропишите оба хоста в `/etc/hosts` на IP ingress-контроллера.

## 4. ArgoCD (два Application — по одному на namespace)

Установка ArgoCD — как раньше:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

kubectl -n argocd port-forward svc/argocd-server 8080:443
# UI: https://localhost:8080  логин: admin / пароль выше
```

Деплой обоих окружений через GitOps: в `argocd/app-dev.yaml` и
`argocd/app-prod.yaml` укажите свой `repoURL`, затем:

```bash
kubectl apply -f argocd/app-dev.yaml
kubectl apply -f argocd/app-prod.yaml
```

Каждый `Application` указывает на свой overlay (`overlays/dev` / `overlays/prod`)
и свой `destination.namespace` (`dev` / `prod`). `syncOptions: CreateNamespace=true`
— ArgoCD сам создаст namespace при первом синке, руками создавать не обязательно.

Проверка:
```bash
kubectl get application -n argocd
kubectl get pods -n dev  -l app=server-info
kubectl get pods -n prod -l app=server-info
```

### Опционально: один ApplicationSet вместо двух Application

Если захочется не дублировать `app-dev.yaml`/`app-prod.yaml`, это можно
свернуть в один `ApplicationSet` с генератором по списку `[dev, prod]` —
скажите, и я соберу такой вариант.
