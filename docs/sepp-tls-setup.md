# SEPP TLS Setup for Roaming

This document describes how to set up TLS encryption for SEPP (Security Edge Protection Proxy) nodes in the Open5GS roaming setup.

## Overview

The SEPP component is used in 5G networks for securing communications between different network operators. By enabling TLS, we ensure that all N32 interface communication between the Home PLMN (HPLMN) and Visited PLMN (VPLMN) is encrypted and secured.

## Automatic TLS Certificate Generation and Exchange

In this roaming setup, TLS certificates are automatically generated and exchanged between SEPP containers. The process works as follows:

1. Each SEPP container generates its own TLS certificates on startup
2. Certificates are stored within the container at `/etc/open5gs/tls/`
3. CA certificates are shared between SEPPs via a shared Docker volume
4. A trusted CA bundle is created containing all peer CA certificates

### How It Works

When the SEPP containers start, the entrypoint script:

- Generates CA, server, and client certificates
- Shares the CA certificate in a common volume accessible to all SEPPs
- Retrieves other SEPPs' CA certificates
- Creates a trusted CA bundle for verifying peer certificates
- Starts the SEPP service with TLS enabled

This automatic exchange enables secure mutual TLS authentication between the Home SEPP and Visited SEPP without manual certificate distribution.

## Starting the Roaming Setup

To start the containers with TLS enabled and proper roaming support:

```bash
# Clean rebuild of SEPP images with certificate exchange
./scripts/rebuild_sepp_images.sh

# Or manually
cd compose-files/roaming
docker-compose up -d
```

## Verifying Roaming TLS Setup

To verify that TLS roaming is working correctly:

1. Check the container logs for certificate generation and exchange messages:

   ```bash
   docker logs h-sepp | grep "CA certificate"
   docker logs v-sepp | grep "CA certificate"
   ```

2. Look for successful TLS handshakes between SEPPs:

   ```bash
   docker logs h-sepp | grep "handshake"
   docker logs v-sepp | grep "handshake"
   ```

3. Test HTTPS connectivity to each SEPP:
   ```bash
   curl -k https://localhost:10443
   curl -k https://localhost:20443
   ```

## Roaming TLS Configuration

The YAML configuration files enable mutual TLS verification between SEPPs:

```yaml
sepp:
  default:
    tls:
      client:
        ca_cert: /etc/open5gs/tls/trusted-ca-bundle.crt # Contains all peer CA certs
  n32:
    server:
      - sender: sepp.5gc.mnc001.mcc001.3gppnetwork.org
        tls:
          enabled: true
          verify_client: true
    client:
      sepp:
        - receiver: sepp.5gc.mnc070.mcc999.3gppnetwork.org
          uri: https://sepp.5gc.mnc070.mcc999.3gppnetwork.org:443
          tls:
            enabled: true
            verify_server: true
```

## Troubleshooting

- **Certificate Exchange Failures**: Check if the shared volume is properly mounted
- **Verification Failures**: Ensure both SEPPs can access each other's CA certificates
- **TLS Handshake Failures**:
  - Check logs with `docker logs h-sepp | grep -E "TLS|handshake|certificate"`
  - Verify the trusted CA bundle contains all necessary certificates
- **Connection Refused**: Ensure both SEPPs are running and ports are correctly mapped

## Advanced: Using Custom Certificates for Roaming

If you prefer to manage certificates manually:

1. Create your own CA and certificates for each SEPP
2. Ensure each SEPP has the other's CA certificate
3. Mount the certificates into each container:
   ```yaml
   volumes:
     - ./your-custom-certs:/etc/open5gs/tls
   ```

## References

- [Open5GS SEPP Documentation](https://open5gs.org/open5gs/docs/guide/01-quickstart/)
- [3GPP TS 33.501](https://www.3gpp.org/DynaReport/33501.htm) - Security architecture and procedures for 5G System
- [3GPP TS 29.573](https://www.3gpp.org/ftp/Specs/archive/29_series/29.573/) - N32 interface for secure packet routing
