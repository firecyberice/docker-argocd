ARG ARGOCD_VERSION=quay.io/argoproj/argocd:v2.3.4
ARG GOLANG_VERSION=1.21

FROM golang:${GOLANG_VERSION} as builder
ARG HELM_SOPS_VERSION=20201003-1
RUN git clone --branch=${HELM_SOPS_VERSION} --depth=1 https://github.com/camptocamp/helm-sops && \
    cd helm-sops && \
    go build

FROM alpine:latest AS downloader
RUN apk add --no-cache curl
ARG HELMFILE_VERSION="v0.144.0"
RUN curl -sLo /usr/local/bin/helmfile https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64 && \
    chmod +x /usr/local/bin/helmfile
ARG YQ_VERSION=v4.25.1
RUN curl -sLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq
ARG SOPS_VERSION=v3.7.3
RUN curl -sLo /usr/local/bin/sops https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 && \
    chmod +x /usr/local/bin/sops

FROM ${ARGOCD_VERSION} as release
USER root
COPY argocd-repo-server-wrapper /usr/local/bin/
COPY argocd-helmfile /usr/local/bin/
COPY --from=builder /go/helm-sops/helm-sops /usr/local/bin/
RUN cd /usr/local/bin && \
    mv argocd-repo-server _argocd-repo-server && \
    mv argocd-repo-server-wrapper argocd-repo-server && \
    chmod 755 argocd-repo-server && \
    mv helm _helm && \
    mv helm-sops helm

COPY --from=downloader /usr/local/bin/ /usr/local/bin/

ARG HELM_DIFF_VERSION="3.4.0"
ARG HELM_SECRETS_VERSION="2.0.3"
ARG HELM_S3_VERSION="0.10.0"
ARG HELM_X_VERSION="0.8.1"
ARG HELM_GIT_VERSION="0.11.1"

RUN apt-get update && \
    apt-get install -y \
        curl \
        gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
USER argocd
# helm plugins should be installed as user argocd or it won't be found
RUN helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION} && \
    helm plugin install https://github.com/hypnoglow/helm-s3.git --version ${HELM_S3_VERSION} && \
    helm plugin install https://github.com/mumoshu/helm-x --version ${HELM_X_VERSION} && \
    helm plugin install https://github.com/aslafy-z/helm-git.git --version ${HELM_GIT_VERSION}
#    helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION} && \
