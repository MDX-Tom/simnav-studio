# syntax=docker/dockerfile:1.7

# The `jammy-slim` tag is a runtime-only image and does not include `swift build`.
FROM swift:6.1.3-jammy@sha256:cb9552a535de8d1a92373351a35ced3813791b6cca6a380bdf179ff3f3122803 AS builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /source
COPY app/Package.swift app/Package.resolved ./
COPY app/NavPlanner ./NavPlanner
COPY app/LocalWeb ./LocalWeb
RUN --mount=type=cache,target=/root/.cache/org.swift.swiftpm \
    --mount=type=cache,target=/source/.build/repositories \
    --mount=type=cache,target=/source/.build/checkouts \
    swift build \
    --configuration release \
    --product simnav-local-web \
    --static-swift-stdlib

FROM builder AS tester
RUN --mount=type=cache,target=/root/.cache/org.swift.swiftpm \
    --mount=type=cache,target=/source/.build/repositories \
    --mount=type=cache,target=/source/.build/checkouts \
    swift test --configuration release list \
    > /source/.build/simnav-test-list.txt \
    && test -s /source/.build/simnav-test-list.txt

FROM ubuntu:22.04@sha256:3b06811b2afd352be909dd088a004166d665dc76d38b13eada33522a9d915c6f

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        libsqlite3-0 \
        tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /var/lib/simnav --uid 10001 simnav \
    && mkdir -p /opt/simnav/Web /opt/simnav/Database /var/lib/simnav/data \
    && chown -R simnav:simnav /var/lib/simnav

COPY --from=builder /source/.build/release/simnav-local-web /usr/local/bin/simnav-local-web
COPY app/NavPlanner/Resources/Web /opt/simnav/Web
COPY app/NavPlanner/Resources/Database/navdata.sqlite /opt/simnav/Database/navdata.sqlite

ENV SIMNAV_CONTAINER=1 \
    SIMNAV_BIND_HOST=0.0.0.0 \
    SIMNAV_WEB_PORT=8010 \
    SIMNAV_WEB_ROOT=/opt/simnav/Web \
    SIMNAV_DATABASE=/opt/simnav/Database/navdata.sqlite \
    SIMNAV_DATA_DIR=/var/lib/simnav/data

USER 10001:10001
EXPOSE 8010
ENTRYPOINT ["/usr/local/bin/simnav-local-web"]
