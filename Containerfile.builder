FROM quay.io/centos/centos:stream9 as os
RUN \
  dnf install -y \
    bc \
    hostname \
    git \
    gcc-toolset-13-libatomic-devel \
    glibc-langpack-en \
    java-1.8.0-openjdk-headless \
    jq \
    sudo && \
  dnf install -y \
    epel-release && \
  dnf clean packages
RUN mkdir -p /ceph /.ccache

FROM os as deps
ARG CEPH_REPO=https://github.com/ceph/ceph
ARG CEPH_BRANCH=main
ARG CLONE_CEPH=1
WORKDIR /
RUN \
  if [ "$CLONE_CEPH" = "1" ]; then \
    git clone --depth 1 --shallow-submodules -b $CEPH_BRANCH $CEPH_REPO ./ceph; \
  fi && \
  cd ceph && \
  ./install-deps.sh && \
  cd .. && \
  dnf clean all && \
  rm -rf /var/cache/dnf/* && \
  if [ "$CLONE_CEPH" = "1" ]; then \
    rm -rf ceph; \
  fi

FROM deps as sccache
ARG SCCACHE_VERSION=v0.8.0
WORKDIR /tmp
RUN \
  curl -L -o sccache.tar.gz https://github.com/mozilla/sccache/releases/download/$SCCACHE_VERSION/sccache-$SCCACHE_VERSION-$(uname -m)-unknown-linux-musl.tar.gz && \
  tar -xzf sccache.tar.gz && \
  mv sccache-*/sccache /usr/bin/ && \
  chown root:root /usr/bin/sccache && \
  restorecon -v /usr/bin/sccache && \
  rm -rf sccache*
COPY sccache_anon_s3.conf /etc/sccache.conf
COPY --chmod=555 build.sh /usr/local/bin/build-ceph.sh

FROM sccache as cmake
WORKDIR /ceph
ENV ARGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo"
ENV SCCACHE_CONF=/etc/sccache.conf
ENV SCCACHE_ERROR_LOG=/ceph/sccache.log
CMD /usr/local/bin/build-ceph.sh
