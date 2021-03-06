FROM golang:1.16-alpine AS builder

ENV GO111MODULE=on
ENV GOPROXY=https://goproxy.cn,direct
ARG user
ENV HOST_USER=$user

WORKDIR /repo

ADD go.mod .
ADD go.sum .

ADD . ./

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --no-cache bash tzdata

ENV TZ="Asia/Shanghai"

RUN go mod tidy && go mod vendor

RUN export GDD_VER=$(go list -mod=vendor -m -f '{{ .Version }}' github.com/unionj-cloud/go-doudou) && \
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -v -ldflags="-X 'github.com/unionj-cloud/go-doudou/framework/buildinfo.BuildUser=$HOST_USER' -X 'github.com/unionj-cloud/go-doudou/framework/buildinfo.BuildTime=$(date)' -X 'github.com/unionj-cloud/go-doudou/framework/buildinfo.GddVer=$GDD_VER'" -mod vendor -o api cmd/main.go

ENTRYPOINT ["/repo/api"]

FROM ubuntu/prometheus:latest

RUN apt-get update; apt-get -y install curl

ENV TZ="Asia/Shanghai"
ENV PROM_SD_OUT=/etc/prometheus/sd

COPY ./prometheus/  /etc/prometheus/

WORKDIR /repo

ADD ./scripts/start.sh start.sh
RUN chmod 755 start.sh

COPY --from=builder /repo/api api
COPY --from=builder /repo/.env .env
COPY --from=builder /repo/.env.prod .env.prod

ENTRYPOINT [ "/usr/bin/env" ]
CMD ["/bin/bash", "/repo/start.sh"]
