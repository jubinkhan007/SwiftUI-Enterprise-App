# ================================
# Build image
# ================================
FROM swift:5.9-jammy AS build

WORKDIR /build

# Copy SharedModels first (dependency)
COPY SharedModels/ SharedModels/

# Copy backend package
COPY Backend/Package.swift Backend/Package.swift

WORKDIR /build/Backend

# Resolve dependencies
RUN swift package resolve

# Copy backend source
COPY Backend/Sources Sources/
COPY Backend/Tests Tests/

# Build with optimizations
RUN swift build -c release --static-swift-stdlib

# ================================
# Runtime image
# ================================
FROM ubuntu:jammy

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built binary
COPY --from=build /build/Backend/.build/release/App .

# Create non-root user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
USER vapor:vapor

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all

EXPOSE 8080

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
