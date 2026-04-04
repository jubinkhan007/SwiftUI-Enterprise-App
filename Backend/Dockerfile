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
# NOTE: We do NOT use --static-swift-stdlib here so that crypto operations
# (Bcrypt, JWT) use the system OpenSSL instead of statically-linked BoringSSL.
# This prevents SIGILL crashes on VPS hosts with restricted CPU instruction sets.
RUN swift build -c release

# ================================
# Runtime image
# ================================
FROM swift:5.9-jammy-slim

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get install -y --no-install-recommends libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built binary
COPY --from=build /build/Backend/.build/release/App .

# Create non-root user and writable data directory for SQLite
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor \
    && mkdir -p /data && chown vapor:vapor /data
USER vapor:vapor

# Disables BoringSSL hardware-accelerated crypto that crashes on some VPS hosts
ENV OPENSSL_ia32cap=0
ENV DATABASE_PATH=/data/enterprise_app.db

EXPOSE 8080

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
