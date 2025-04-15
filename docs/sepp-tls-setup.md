# SEPP TLS Setup for Roaming

This document describes how to set up TLS encryption for SEPP (Security Edge Protection Proxy) nodes in the Open5GS roaming setup.

## Overview

The SEPP component is used in 5G networks for securing communications between different network operators. By enabling TLS, we ensure that all N32 interface communication between the Home PLMN (HPLMN) and Visited PLMN (VPLMN) is encrypted and secured.

## Prerequisites

- Docker and Docker Compose installed
- Open5GS roaming setup already configured

## Automated Setup

The simplest way to set up TLS for SEPP is to use the provided setup script:

```bash
# Run the setup script
./scripts/setup_sepp_tls_roaming.sh
```

This script will:

1. Generate the TLS certificates for both Home SEPP and Visited SEPP
2. Verify that the YAML configurations are correct
3. Provide instructions for starting the containers

## Manual Setup

If you prefer to set up TLS manually, follow these steps:

### 1. Generate TLS Certificates

Run the certificate generation script:

```bash
./scripts/generate_sepp_tls.sh
```

This will create:

- CA certificate and key
- Server certificates and keys for both Home SEPP and Visited SEPP
- Client certificates and keys for mutual TLS authentication

The certificates will be stored in the `tls/sepp` directory.

### 2. Modify SEPP Configurations

Update the SEPP configuration files to enable TLS:

- `configs/roaming/h-sepp.yaml` - Home SEPP configuration
- `configs/roaming/v-sepp.yaml` - Visited SEPP configuration

Ensure the following TLS configuration is present in both files:

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

Also ensure that the SBI and N32 interfaces are configured to use TLS:

```yaml
sbi:
  server:
    - address: sepp.5gc.mnc001.mcc001.3gppnetwork.org # or your SEPP FQDN
      port: 443
      tls:
        enabled: true
n32:
  server:
    - sender: sepp.5gc.mnc001.mcc001.3gppnetwork.org # or your SEPP FQDN
      tls:
        enabled: true
  client:
    sepp:
      - receiver: sepp.5gc.mnc070.mcc999.3gppnetwork.org # the other SEPP FQDN
        uri: https://sepp.5gc.mnc070.mcc999.3gppnetwork.org:443
        tls:
          enabled: true
```

### 3. Update Docker Compose Configuration

Modify the `compose-files/roaming/docker-compose.yaml` file to mount the TLS certificates into the SEPP containers:

```yaml
h-sepp:
  # ... existing configuration ...
  volumes:
    - ../../tls/sepp/h-sepp:/etc/open5gs/tls
  ports:
    - '10443:443/tcp'

v-sepp:
  # ... existing configuration ...
  volumes:
    - ../../tls/sepp/v-sepp:/etc/open5gs/tls
  ports:
    - '20443:443/tcp'
```

### 4. Start the Containers

Start the Docker containers with:

```bash
cd compose-files/roaming
docker-compose up -d
```

## Testing TLS Connectivity

To verify that TLS is correctly configured:

1. Check the logs of both SEPP containers:

   ```bash
   docker logs h-sepp
   docker logs v-sepp
   ```

2. You should see messages indicating successful TLS handshakes between the SEPPs.

3. Test HTTPS connectivity with:
   ```bash
   curl -k https://localhost:10443
   curl -k https://localhost:20443
   ```

## Troubleshooting

- **Certificate Issues**: Ensure the certificates are properly mounted and accessible in the containers.
- **TLS Handshake Failures**: Check that both SEPPs are using the same CA certificate.
- **Connection Refused**: Verify the port mappings and that the containers are running.
- **Container Crashes**: Inspect logs for any errors related to TLS configuration.

## References

- [Open5GS SEPP Documentation](https://open5gs.org/open5gs/docs/guide/01-quickstart/)
- [3GPP TS 33.501](https://www.3gpp.org/DynaReport/33501.htm) - Security architecture and procedures for 5G System
