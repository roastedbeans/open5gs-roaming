# Overview of the roaming deployment

The `roaming` deployment is prepared to work with Open5GS Local Breakout (LBO) Roaming feature and PacketRusher(gNB and UE), only exposing the MongoDB database using `TCP port 27017`.

Two 5G Cores are deployed for this example, one for the visited network (with PLMN 999 70) and one for the home network (with PLMN 001 01).

This example only deploys the minimum number of Network Functions in order to test the setup. One database is used, for the home network user authentication. So, in this case, the UE with IMSI 001011234567891 must be present on the database. The Roaming agreement is present on the visited network PCF (v-pcf) configuration file, under the `policy` section. That is because the visited network does not have any information for the user apart from that.

The communication between the two 5G Cores is done via the SEPP Network Functions.

![Overview of the roaming deployment](../../misc/diagrams/roaming.png)

Even though, the two SBI sections are separated in the diagram, only one docker network is created so in reality everything is interconnected. This is shown this way for a better understanding.

## Architecture Components

### Home Network (PLMN: 001 01)

- h-nrf: Network Repository Function (Central registry)
- h-ausf: Authentication Server Function
- h-udm: Unified Data Management
- h-udr: Unified Data Repository (Contains subscriber data)
- h-sepp: Security Edge Protection Proxy (Handles inter-PLMN communication)

### Visited Network (PLMN: 999 70)

- v-nrf: Network Repository Function
- v-ausf: Authentication Server Function
- v-nssf: Network Slice Selection Function
- v-bsf: Binding Support Function
- v-pcf: Policy Control Function
- v-amf: Access and Mobility Management Function
- v-smf: Session Management Function
- v-upf: User Plane Function
- v-sepp: Security Edge Protection Proxy

### Test Tools

- PacketRusher: gNB and UE simulator
- WebUI: Management interface for Open5GS

## Setup Process

### Prerequisites

- Docker and Docker Compose installed
- 4+ GB of RAM available
- Port 27017, 7777-7779, 8777-8779, and 9999 open on your host

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-repo/docker-open5gs.git
cd docker-open5gs
```

### Step 2: Configure Environment

Create a `.env` file in the root directory if not already present:

```
OPEN5GS_VERSION=latest
UBUNTU_VERSION=22.04
MONGODB_VERSION=6.0
NODE_VERSION=16
```

### Step 3: Start the Deployment

```bash
cd compose-files/roaming
docker-compose up -d
```

### Step 4: Verify Container Status

```bash
docker-compose ps
```

All services should be in the "Up" state.

## Post-Setup Configuration

### Step 1: Configure Subscriber Information

Access the WebUI at http://localhost:9999 with credentials:

- Username: admin
- Password: 1423

Add a subscriber with the following details:

- IMSI: 001011234567891
- Key: 7F176C500D47CF2090CB6D91F4A73479
- OPc: 3D45770E83C7BBB6900F3653FDA6330F
- HPLMN: 001 01
- DNN: internet
- SST: 1, SD: 000001

### Step 2: Verify Network Connectivity

You can verify the connectivity between components using the following methods:

1. Check container-to-container communication:

```bash
docker exec -it packetrusher ping amf.5gc.mnc070.mcc999.3gppnetwork.org
```

2. Verify SEPP communication between home and visited networks:

```bash
docker exec -it h-sepp ping v-sepp.5gc.mnc070.mcc999.3gppnetwork.org
docker exec -it v-sepp ping h-sepp.5gc.mnc001.mcc001.3gppnetwork.org
```

### Step 3: Test UE Registration

PacketRusher is already configured to simulate a UE with the IMSI 001011234567891. You can check registration status:

```bash
docker exec -it packetrusher tail -f /PacketRusher/logs/packetrusher.log
```

Look for successful registration and PDU session establishment messages.

## Troubleshooting

### Log Inspection

View logs from specific containers:

```bash
docker logs h-nrf
docker logs v-amf
docker logs packetrusher
```

### Network Function Connectivity

Check if network functions can reach each other:

```bash
docker exec -it v-amf ping h-sepp.5gc.mnc001.mcc001.3gppnetwork.org
```

### SEPP Connectivity

Verify SEPP N32 interfaces:

```bash
docker exec -it h-sepp curl -k https://v-sepp.5gc.mnc070.mcc999.3gppnetwork.org:7778/
```

### Database Connection

Verify MongoDB connection:

```bash
docker exec -it db mongo --eval "db.adminCommand('ping')"
```

## Customizing the Deployment

### Modifying Network Function Configurations

Configuration files for all network functions are located in `configs/roaming/`. Edit these files to change parameters like:

- SBI interfaces
- Network slices
- UE policies
- Roaming agreements

After changes, restart the affected components:

```bash
docker-compose restart v-pcf
```

### Changing PacketRusher Configuration

To modify the UE/gNB configuration:

1. Edit `configs/roaming/packetrusher.yaml`
2. Restart the PacketRusher container:

```bash
docker-compose restart packetrusher
```

## Advanced Usage

### Observing Traffic

You can capture network traffic between components:

```bash
docker exec -it v-upf tcpdump -i any -n
```

### Load Testing

To test with multiple simultaneous UE connections, modify the PacketRusher configuration to include multiple IMSIs and restart the container.

## Clean Up

To stop and remove all containers:

```bash
docker-compose down
```

To completely clean up including volumes:

```bash
docker-compose down -v
```
