# Use a slim Debian-based image
FROM alpine:3.20

# Install curl
RUN apk add --no-cache curl jq

WORKDIR /opt

# Copy the script
COPY oidc-utils.sh .

# Make the script executable
RUN chmod +x /opt/oidc-utils.sh

ENTRYPOINT ["/bin/sh", "/opt/oidc-utils.sh"]
