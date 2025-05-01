# Open5GS Roaming Setup: Complete Guide

This document provides a comprehensive summary of the entire Open5GS roaming setup process, compiling key information from all documentation sections into a single reference guide.

## 1. System Architecture

The Open5GS roaming setup simulates communication between two mobile network operators:

- **Home Network (H-PLMN)**: MCC 001, MNC 01
- **Visiting Network (V-PLMN)**: MCC 999, MNC 70

### Network Components

The setup consists of the following components:

#### Home Network Components (MCC-001, MNC-01)

- **h-nrf**: Network Repository Function - Central registry for network functions
- **h-ausf**: Authentication Server Function - Handles authentication
- **h-udm**: Unified Data Management - Manages subscriber data
- **h-udr**: Unified Data Repository - Stores subscriber data
- **h-sepp**: Security Edge Protection Proxy - Secures inter-PLMN communication

#### Visiting Network Components (MCC-999, MNC-70)

- **v-nrf**: Network Repository Function
- **v-ausf**: Authentication Server Function
- **v-nssf**: Network Slice Selection Function
- **v-bsf**: Binding Support Function
- **v-pcf**: Policy Control Function
- **v-amf**: Access and Mobility Management Function
- **v-smf**: Session Management Function
- **v-upf**: User Plane Function
- **v-sepp**: Security Edge Protection Proxy

#### Supporting Components

- **db**: MongoDB database for storing subscriber information
- **webui**: Web user interface for managing the system
- **tshark**: Packet capture utility
- **packetrusher**: gNB and UE simulator

### Network Topology

All components run as Docker containers on a bridge network named `open5gs` with subnet `10.33.33.0/24`.

**IP Addressing Scheme (Key Components)**:
| Component | IP Address | FQDN |
| --------- | ----------- | -------------------------------------- |
| h-nrf | 10.33.33.10 | nrf.5gc.mnc001.mcc001.3gppnetwork.org |
| h-sepp | 10.33.33.20 | sepp.5gc.mnc001.mcc001.3gppnetwork.org |
| v-nrf | 10.33.33.30 | nrf.5gc.mnc070.mcc999.3gppnetwork.org |
| v-amf | 10.33.33.35 | amf.5gc.mnc070.mcc999.3gppnetwork.org |
| v-upf | 10.33.33.37 | upf.5gc.mnc070.mcc999.3gppnetwork.org |
| v-sepp | 10.33.33.21 | sepp.5gc.mnc070.mcc999.3gppnetwork.org |

### SEPP and TLS Setup

The SEPPs secure communication between networks using TLS:

- **h-sepp**: Ports 7777 (SBI), 7778 (N32c), 7779 (N32f)
- **v-sepp**: Ports 8777 (SBI), 8778 (N32c), 8779 (N32f)

### User Equipment Configuration

- **IMSI**: 001010000000001
- **Key**: 7F176C500D47CF2090CB6D91F4A73479
- **OPC**: 3D45770E83C7BBB6900F3653FDA6330F
- **Default DNN**: internet
- **Network Slice**: SST: 01, SD: 000001

## 2. Environment Setup

### System Requirements

- Ubuntu 22.04 LTS (recommended)
- Minimum 8GB RAM, 4 CPU cores
- 50GB of free disk space
- Virtualization capability (if not running Linux natively)

### Required Software

- Docker and Docker Compose
- Git
- GTP5G Kernel Module
- Wireshark (for packet analysis)

### Automated Installation

```bash
git clone https://github.com/roastedbeans/open5gs-roaming.git
cd open5gs-roaming
chmod +x install-dep.sh
./install-dep.sh
```

### Manual Installation

#### Docker Installation

```bash
# Remove old Docker versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc
# Update package index and install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Set up the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Add current user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### GTP5G Kernel Module Installation

```bash
# Install build dependencies
sudo apt-get install -y build-essential linux-headers-$(uname -r) git
# Clone and build GTP5G module
cd /usr/src
sudo git clone https://github.com/free5gc/gtp5g.git
cd gtp5g
sudo make clean
sudo make
sudo make install
# Load the module
sudo modprobe gtp5g
# Make it load at boot
echo "gtp5g" | sudo tee /etc/modules-load.d/gtp5g.conf
```

## 3. Installation

### Cloning the Repository

```bash
git clone https://github.com/roastedbeans/open5gs-roaming.git
cd open5gs-roaming
```

### Building Docker Images

**Option 1: Using Docker Bake**

```bash
# Build all components at once
docker buildx bake -f docker-bake.hcl

# Build specific components
docker buildx bake -f docker-bake.hcl base
docker buildx bake -f docker-bake.hcl nrf ausf udm
```

**Option 2: Using Make**

```bash
# Build all components
make all

# Build components individually
make base-open5gs
make amf
make ausf
# etc.
```

### Docker Volumes

- `db_data`: MongoDB database data
- `db_config`: MongoDB configuration data
- `sepp_certs`: TLS certificates for SEPP components
- `sepp_ca`: Certificate Authority for SEPP components
- `captures`: Network packet captures from tshark

## 4. Running the System

### Starting the Containers

```bash
cd open5gs-roaming/compose-files/roaming
docker-compose up -d
```

### Adding a Subscriber

1. Access WebUI at `http://localhost:9999` (login: admin/1423)
2. Add a subscriber with these details:
   - IMSI: `001010000000001`
   - Subscriber Key (K): `7F176C500D47CF2090CB6D91F4A73479`
   - OPc: `3D45770E83C7BBB6900F3653FDA6330F`
   - Slice: SST: `1`, SD: `000001`
   - DNN: `internet`

### Monitoring Network Functions

**Viewing Container Logs**

```bash
docker-compose logs            # All containers
docker-compose logs v-amf      # Specific container
docker-compose logs -f         # Follow logs
```

**Checking Component Status**

```bash
# Verify SEPP TLS setup
docker exec -it h-sepp ls -la /etc/open5gs/default/tls
docker exec -it v-sepp ls -la /etc/open5gs/default/tls

# Check NRF registrations
docker exec -it h-nrf curl -s http://nrf.5gc.mnc001.mcc001.3gppnetwork.org:7777/nnrf-nfm/v1/nf-instances | jq
docker exec -it v-nrf curl -s http://nrf.5gc.mnc070.mcc999.3gppnetwork.org:7777/nnrf-nfm/v1/nf-instances | jq
```

### Running the UE Test

```bash
# Check UE logs
docker-compose logs packetrusher

# Test connectivity
docker exec -it packetrusher /bin/sh
ping -I uesimtun0 8.8.8.8
```

### Stopping the System

```bash
docker-compose down      # Preserve data
docker-compose down -v   # Remove all data
```

## 5. Testing and Verification

### Basic Operation Testing

**Verify Network Function Registration**

```bash
# Home NRF
docker exec -it h-nrf curl -s http://nrf.5gc.mnc001.mcc001.3gppnetwork.org:7777/nnrf-nfm/v1/nf-instances | jq

# Visiting NRF
docker exec -it v-nrf curl -s http://nrf.5gc.mnc070.mcc999.3gppnetwork.org:7777/nnrf-nfm/v1/nf-instances | jq
```

**Verify SEPP Connectivity**

```bash
docker-compose logs h-sepp | grep "connection established"
docker-compose logs v-sepp | grep "connection established"
```

**Verify UE Registration and PDU Session**

```bash
docker-compose logs packetrusher | grep "Registration"
docker-compose logs packetrusher | grep "PDU Session"
```

### Data Connectivity Testing

```bash
# Test internet connectivity
docker exec -it packetrusher /bin/sh
ping -I uesimtun0 8.8.8.8

# Test DNS resolution
nslookup -i uesimtun0 google.com

# Test bandwidth
wget -O /dev/null http://speedtest.ftp.otenet.gr/files/test100k.db
```

### Roaming Functionality Testing

**Verify Inter-PLMN Communication**

```bash
docker-compose logs h-sepp | grep "N32-f"
docker-compose logs v-sepp | grep "N32-f"
```

**Verify UE Identity Protection**

```bash
docker-compose logs v-amf | grep "SUCI"
```

### Troubleshooting Tests

**Check Component Health**

```bash
for container in $(docker-compose ps -q); do
  echo -n "Container: "
  docker inspect --format='{{.Name}}' $container
  echo -n "Status: "
  docker inspect --format='{{.State.Status}}' $container
  echo -n "Health: "
  docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' $container
  echo "------------------------------"
done
```

**Check Network Connectivity**

```bash
# Test connectivity from V-AMF to H-SEPP
docker exec -it v-amf ping -c 3 sepp.5gc.mnc001.mcc001.3gppnetwork.org

# Test connectivity from H-SEPP to V-SEPP
docker exec -it h-sepp ping -c 3 sepp.5gc.mnc070.mcc999.3gppnetwork.org
```

## 6. Common Troubleshooting

1. **Container fails to start**: Check logs with `docker-compose logs [container_name]`
2. **UE fails to register**: Verify subscriber data in WebUI matches UE configuration
3. **SEPPs not connecting**: Check SEPP logs and TLS certificate generation
4. **No data connectivity**: Check UPF logs and gtp5g kernel module installation

## 7. Additional Resources

- [Open5GS Documentation](https://open5gs.org/open5gs/docs/)
- [PacketRusher Documentation](https://github.com/HewlettPackard/PacketRusher)
- [3GPP Technical Specifications](https://www.3gpp.org/specifications/specifications)
