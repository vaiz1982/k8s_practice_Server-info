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






















<img width="1201" height="486" alt="Screenshot 2026-07-08 at 17 29 57" src="https://github.com/user-attachments/assets/b02ef25a-be50-4be8-8c61-c69cb4c431da" />













<img width="1063" height="460" alt="Screenshot 2026-07-08 at 17 44 04" src="https://github.com/user-attachments/assets/2e1ce3d6-61f9-4b4f-b527-b5378f12b0b7" />

















<img width="1322" height="951" alt="Screenshot 2026-07-08 at 17 48 35" src="https://github.com/user-attachments/assets/054f417c-cda5-4765-a075-27e41a9b9241" />













<img width="1110" height="382" alt="Screenshot 2026-07-08 at 17 53 13" src="https://github.com/user-attachments/assets/c86d8963-8b4b-444f-9fc5-a31f26be8d65" />














<img width="1411" height="924" alt="Screenshot 2026-07-08 at 17 54 52" src="https://github.com/user-attachments/assets/7553aef4-658f-42a0-b23d-a004a9dfee83" />















<img width="1406" height="919" alt="Screenshot 2026-07-08 at 17 59 19" src="https://github.com/user-attachments/assets/bce61a83-804f-45a5-9be7-c86fc5faf08d" />
















<img width="1396" height="543" alt="Screenshot 2026-07-08 at 18 00 15" src="https://github.com/user-attachments/assets/62de6890-fe22-45f9-ab9c-1dfe1d2604cc" />

















<img width="635" height="664" alt="Screenshot 2026-07-08 at 18 04 50" src="https://github.com/user-attachments/assets/8ab6aaa6-a84e-417d-bc47-602600a628ba" />


















<img width="1405" height="780" alt="Screenshot 2026-07-08 at 18 06 51" src="https://github.com/user-attachments/assets/69a43947-7743-48d3-ab6d-e213eafc482c" />















<img width="1831" height="868" alt="Screenshot 2026-07-08 at 18 23 46" src="https://github.com/user-attachments/assets/62067266-b94f-440e-b153-6fa52eee467c" />



















<img width="1842" height="688" alt="Screenshot 2026-07-08 at 18 26 09" src="https://github.com/user-attachments/assets/2166d84b-51d4-4516-b4cf-59dd572b622c" />















<img width="1407" height="415" alt="Screenshot 2026-07-08 at 18 31 18" src="https://github.com/user-attachments/assets/8010911a-0ae8-44fb-8426-f7e3cc30a70f" />













<img width="1829" height="1003" alt="Screenshot 2026-07-08 at 18 32 15" src="https://github.com/user-attachments/assets/959bd93e-865e-48d8-8dc0-b82d54d8379e" />















<img width="1099" height="144" alt="Screenshot 2026-07-08 at 18 32 28" src="https://github.com/user-attachments/assets/74b32ad1-514c-44ba-ac8c-86381dd23987" />












argocd own it ?



<img width="995" height="161" alt="Screenshot 2026-07-08 at 18 33 43" src="https://github.com/user-attachments/assets/fb80db1e-86b6-4386-8ea9-3e862b69c89d" />





