# SEPP TLS Setup for Roaming

This document describes how to set up TLS encryption for SEPP (Security Edge Protection Proxy) nodes in the Open5GS roaming setup.

## Overview

The SEPP component is used in 5G networks for securing communications between different network operators. By enabling TLS, we ensure that all N32 interface communication between the Home PLMN (HPLMN) and Visited PLMN (VPLMN) is encrypted and secured.

## Automatic TLS Certificate Generation

In this setup, TLS certificates are automatically generated when the SEPP containers start. The process works as follows:

1. The SEPP Docker image includes an entrypoint script (`sepp-entrypoint.sh`) that generates certificates if they don't exist
2. Each SEPP container (Home SEPP and Visited SEPP) generates its own certificates
3. The certificates are stored within the container at `/etc/open5gs/tls/`

### How it Works

The entrypoint script performs the following actions:

- Checks if certificates already exist in the container
- If certificates don't exist, it generates a CA certificate, server certificate, and client certificate
- It sets the proper file permissions
- Finally, it starts the SEPP process

## Starting the Containers

To start the containers with TLS enabled:

```bash
cd compose-files/roaming
docker-compose up -d
```

## Verifying TLS Setup

To verify that TLS is working correctly:

1. Check the container logs for certificate generation messages:

   ```bash
   docker logs h-sepp
   docker logs v-sepp
   ```

2. Test HTTPS connectivity:
   ```bash
   curl -k https://localhost:10443
   curl -k https://localhost:20443
   ```

## Troubleshooting

- **Certificate Generation Failures**: Check the container logs for any error messages during certificate generation
- **TLS Handshake Failures**: Ensure the SEPP configuration has TLS properly enabled
- **Connection Refused**: Verify the port mappings and that the containers are running
- **Container Crashes**: Inspect logs for any errors related to the TLS configuration

## Advanced: Using Custom Certificates

If you want to use custom certificates instead of auto-generated ones, you can modify the Docker Compose file to mount your own certificates:

```yaml
volumes:
  - ./your-custom-certs:/etc/open5gs/tls
```

Make sure your custom certificates have the following filenames:

- `ca.crt`: CA certificate
- `server.key`: Server private key
- `server.crt`: Server certificate
- `client.key`: Client private key
- `client.crt`: Client certificate

## References

- [Open5GS SEPP Documentation](https://open5gs.org/open5gs/docs/guide/01-quickstart/)
- [3GPP TS 33.501](https://www.3gpp.org/DynaReport/33501.htm) - Security architecture and procedures for 5G System
