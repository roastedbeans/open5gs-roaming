# SEPP Docker Image with TLS Support

This directory contains the Dockerfile and scripts for the SEPP (Security Edge Protection Proxy) component with built-in TLS support.

## Features

- Automatic TLS certificate generation within the container
- Secure communication between SEPP nodes
- Mutual TLS authentication support

## How it Works

The Docker image includes an entrypoint script (`sepp-entrypoint.sh`) that automatically generates TLS certificates when the container starts. This approach ensures:

1. Every container has its own certificates
2. The certificates are correctly generated for the container's hostname
3. No manual certificate management is needed

## Certificate Generation

The entrypoint script performs the following steps:

1. Checks if certificates already exist in `/etc/open5gs/tls/`
2. If not, generates a new CA certificate, server certificate, and client certificate
3. Configures the certificates with the correct permissions
4. Starts the SEPP process

The following certificates are generated:

- `ca.crt`: The CA certificate
- `server.key`: Server private key
- `server.crt`: Server certificate
- `client.key`: Client private key
- `client.crt`: Client certificate

## Building and Running

The image can be built with Docker Compose:

```bash
cd compose-files/roaming
docker-compose build h-sepp v-sepp
```

Or using the provided script:

```bash
./scripts/rebuild_sepp_images.sh
```

## Configuration

The SEPP TLS configuration should be set in the YAML configuration file:

```yaml
sepp:
  default:
    tls:
      server:
        schema: https
        private_key: /etc/open5gs/tls/server.key
        cert: /etc/open5gs/tls/server.crt
        verify_client: true
        ca_cert: /etc/open5gs/tls/ca.crt
      client:
        schema: https
        client_private_key: /etc/open5gs/tls/client.key
        client_cert: /etc/open5gs/tls/client.crt
        ca_cert: /etc/open5gs/tls/ca.crt
```

## Custom Certificates

If you want to use your own certificates instead of the auto-generated ones, you can mount them as a volume:

```yaml
volumes:
  - ./your-custom-certs:/etc/open5gs/tls
```

Make sure your custom certificates use the file names expected by the configuration.
