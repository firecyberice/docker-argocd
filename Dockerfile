ARG ARGOCD_VERSION=quay.io/argoproj/argocd:v2.0.1

FROM golang:1.16 as builder
ARG HELM_SOPS_VERSION=20201003-1
RUN git clone --branch=${HELM_SOPS_VERSION} --depth=1 https://github.com/camptocamp/helm-sops && \
    cd helm-sops && \
    go build

FROM ${ARGOCD_VERSION} as release
USER root
COPY argocd-repo-server-wrapper /usr/local/bin/
COPY --from=builder /go/helm-sops/helm-sops /usr/local/bin/
RUN cd /usr/local/bin && \
    mv argocd-repo-server _argocd-repo-server && \
    mv argocd-repo-server-wrapper argocd-repo-server && \
    mv helm _helm && \
    mv helm2 _helm2 && \
    mv helm-sops helm && \
    ln helm helm2
USER argocd
