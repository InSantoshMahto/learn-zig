FROM alpine:3 AS builder

# Install zig
RUN apk add --no-cache \
    zig

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Build application
RUN zig build -Doptimize=ReleaseSafe

# Runtime stage
FROM scratch

# Copy binary from builder
COPY --from=builder /app/zig-out/bin/api /usr/local/bin/

# Expose port
EXPOSE 8080

# Run application
CMD ["api"]
