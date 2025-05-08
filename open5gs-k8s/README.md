# Open5GS Kubernetes Roaming Testbed

This repository contains Kubernetes manifests for deploying an Open5GS 5G core network with roaming capabilities on Kubernetes with Multus CNI. It is based on the niloysh/open5gs-k8s implementation but extended to support 5G roaming.

## Architecture

The deployment consists of two separate 5G networks:

1. **Home Network (H-PLMN)**: MCC 001, MNC 01

   - h-nrf, h-ausf, h-udm, h-udr, h-sepp

2. **Visiting Network (V-PLMN)**: MCC 999, MNC 70

   - v-nrf, v-ausf, v-nssf, v-bsf, v-pcf, v-amf, v-smf, v-upf, v-sepp

3. **Infrastructure Components**:
   - MongoDB for subscriber data
   - WebUI for management
   - tshark for packet capture
   - PacketRusher for UE simulation

## Prerequisites

- Kubernetes cluster (v1.20+)
- Multus CNI plugin
- Linux nodes with GTP5G kernel module support
- kubectl configured to access your cluster

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/open5gs-k8s.git
cd open5gs-k8s
```
