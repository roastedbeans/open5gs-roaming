#!/bin/bash

# Comprehensive script to set up Open5GS k8s-roaming on Ubuntu 22.04
# This script will:
# 1. Install Docker
# 2. Install MicroK8s
# 3. Pull all necessary Docker images
# 4. Generate TLS certificates
# 5. Set up Kubernetes namespaces and secrets

set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set default Open5GS version
OPEN5GS_VERSION="${1:-v2.7.5}"

# Get the base directory (parent of scripts directory)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_ROAMING_DIR="$BASE_DIR/k8s-roaming"
CERT_DIR="$K8S_ROAMING_DIR/cert"

echo -e "${BLUE}Starting Open5GS k8s-roaming setup with version ${YELLOW}${OPEN5GS_VERSION}${NC}"
echo -e "${BLUE}Base directory: ${YELLOW}${BASE_DIR}${NC}"
echo -e "${BLUE}K8s-roaming directory: ${YELLOW}${K8S_ROAMING_DIR}${NC}"

# Step 1: Install Docker
install_docker() {
  echo -e "${BLUE}Installing Docker...${NC}"
  
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
  
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  # Add current user to docker group
  sudo usermod -aG docker $USER
  
  echo -e "${GREEN}Docker installed successfully${NC}"
  echo -e "${YELLOW}NOTE: You might need to log out and back in for group changes to take effect${NC}"
}

# Step 2: Install MicroK8s
install_microk8s() {
  echo -e "${BLUE}Installing MicroK8s...${NC}"
  
  sudo snap install microk8s --classic --channel=1.28/stable
  sudo usermod -aG microk8s $USER
  
  mkdir -p ~/.kube
  sudo chown -f -R $USER ~/.kube
  
  echo -e "${GREEN}MicroK8s installed successfully${NC}"
  echo -e "${YELLOW}NOTE: You might need to log out and back in for group changes to take effect${NC}"
}

# Step 3: Configure MicroK8s
configure_microk8s() {
  echo -e "${BLUE}Configuring MicroK8s...${NC}"
  
  # Wait for MicroK8s to be ready
  microk8s status --wait-ready
  
  # Enable required addons
  microk8s enable dns storage helm3
  
  # Create an alias for kubectl
  echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
  
  # Create namespaces (with check if they already exist)
  echo -e "${BLUE}Setting up namespaces...${NC}"
  
  # Create HPLMN namespace if it doesn't exist
  if ! microk8s kubectl get namespace hplmn &>/dev/null; then
    echo -e "${BLUE}Creating hplmn namespace...${NC}"
    microk8s kubectl create namespace hplmn
  else
    echo -e "${YELLOW}hplmn namespace already exists, skipping creation${NC}"
  fi
  
  # Create VPLMN namespace if it doesn't exist
  if ! microk8s kubectl get namespace vplmn &>/dev/null; then
    echo -e "${BLUE}Creating vplmn namespace...${NC}"
    microk8s kubectl create namespace vplmn
  else
    echo -e "${YELLOW}vplmn namespace already exists, skipping creation${NC}"
  fi
  
  echo -e "${GREEN}MicroK8s configured successfully${NC}"
}

# Step 4: Pull Docker images
pull_images() {
  echo -e "${BLUE}Pulling Docker images from docker.io/vinch05...${NC}"
  
  # List of all Open5GS components
  COMPONENTS=(
    "base-open5gs"
    "amf"
    "ausf"
    "bsf"
    "nrf"
    "nssf"
    "pcf"
    "scp"
    "sepp"
    "smf"
    "udm"
    "udr"
    "upf"
    "webui"
  )
  
  # Pull each image
  for component in "${COMPONENTS[@]}"; do
    echo "Pulling docker.io/vinch05/${component}:${OPEN5GS_VERSION}..."
    docker pull docker.io/vinch05/${component}:${OPEN5GS_VERSION}
    
    # Check if pull was successful
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ Successfully pulled docker.io/vinch05/${component}:${OPEN5GS_VERSION}${NC}"
    else
      echo -e "${RED}❌ Failed to pull docker.io/vinch05/${component}:${OPEN5GS_VERSION}${NC}"
    fi
  done
  
  # Pull tcpdump image for network packet capture
  echo "Pulling corfr/tcpdump for packet capture..."
  docker pull corfr/tcpdump
  
  echo -e "${GREEN}All images pulled successfully${NC}"
}

# Step 5: Generate TLS certificates
generate_certificates() {
  echo -e "${BLUE}Generating TLS certificates for SEPP...${NC}"
  
  # Ensure cert directory exists
  mkdir -p "$CERT_DIR"
  cd "$CERT_DIR"
  
  # Create the certificate generation script if it doesn't exist
  if [ ! -f "generate-sepp-certs.sh" ]; then
    echo -e "${BLUE}Creating certificate generation script...${NC}"
    cat > generate-sepp-certs.sh << 'EOF'
#!/bin/bash

set -e

TLS_DIR="./open5gs_tls"
mkdir -p "$TLS_DIR"

echo "✅ Creating CA..."
openssl genrsa -out $TLS_DIR/ca.key 2048
openssl req -x509 -new -nodes -key $TLS_DIR/ca.key -sha256 -days 365 \
    -out $TLS_DIR/ca.crt -subj "/CN=SEPP Test CA"

# === Function to generate cert ===
generate_cert() {
  NAME=$1
  CN=$2
  echo "🔐 Generating key and cert for $NAME ($CN)..."
  openssl genrsa -out $TLS_DIR/${NAME}.key 2048
  openssl req -new -key $TLS_DIR/${NAME}.key -out $TLS_DIR/${NAME}.csr \
    -subj "/CN=${CN}"
  openssl x509 -req -in $TLS_DIR/${NAME}.csr -CA $TLS_DIR/ca.crt -CAkey $TLS_DIR/ca.key \
    -CAcreateserial -out $TLS_DIR/${NAME}.crt -days 365 -sha256
  rm $TLS_DIR/${NAME}.csr
}

# === HPLMN (mnc001.mcc001) ===
generate_cert "sepp-hplmn-n32c" "sepp1.5gc.mnc001.mcc001.3gppnetwork.org"
generate_cert "sepp-hplmn-n32f" "sepp2.5gc.mnc001.mcc001.3gppnetwork.org"

# === VPLMN (mnc070.mcc999) ===
generate_cert "sepp-vplmn-n32c" "sepp1.5gc.mnc070.mcc999.3gppnetwork.org"
generate_cert "sepp-vplmn-n32f" "sepp2.5gc.mnc070.mcc999.3gppnetwork.org"

echo "✅ All certificates generated in: $TLS_DIR"
ls -l $TLS_DIR
EOF
  fi
  
  # Try to set execute permissions
  echo -e "${BLUE}Setting execute permissions on certificate script...${NC}"
  chmod +x generate-sepp-certs.sh || true
  
  # Check if script is executable
  if [ -x "generate-sepp-certs.sh" ]; then
    echo -e "${GREEN}Execute permission set successfully${NC}"
    # Run the script directly
    ./generate-sepp-certs.sh
  else
    echo -e "${YELLOW}Warning: Could not set execute permission on script. Trying with bash...${NC}"
    # Run with bash explicitly
    bash generate-sepp-certs.sh
  fi
  
  # Verify certificates were generated
  if [ -f "./open5gs_tls/ca.crt" ]; then
    echo -e "${GREEN}TLS certificates generated successfully in ${YELLOW}${CERT_DIR}/open5gs_tls${NC}"
  else
    echo -e "${RED}Error: Certificate generation failed. TLS files not found.${NC}"
    return 1
  fi
}

# Step 6: Create Kubernetes secrets for TLS
create_k8s_secrets() {
  echo -e "${BLUE}Creating Kubernetes secrets for TLS certificates...${NC}"
  
  # Make sure we're in the cert directory with the generated certificates
  cd "$CERT_DIR"
  
  if [ ! -d "./open5gs_tls" ]; then
    echo -e "${RED}Error: TLS directory not found at ${YELLOW}${CERT_DIR}/open5gs_tls${NC}"
    echo -e "${RED}Please run generate_certificates() first${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Using TLS certificates from ${YELLOW}${CERT_DIR}/open5gs_tls${NC}"
  
  # Function to create or replace a secret
  create_or_replace_secret() {
    local namespace=$1
    local secret_name=$2
    local args="${@:3}"
    
    # Check if secret exists
    if microk8s kubectl -n "$namespace" get secret "$secret_name" &>/dev/null; then
      echo -e "${YELLOW}Secret $secret_name already exists in namespace $namespace, replacing...${NC}"
      # Delete existing secret
      microk8s kubectl -n "$namespace" delete secret "$secret_name"
    else
      echo -e "${BLUE}Creating secret $secret_name in namespace $namespace...${NC}"
    fi
    
    # Create the secret
    microk8s kubectl -n "$namespace" create secret generic "$secret_name" $args
  }
  
  # Create secrets for VPLMN
  echo -e "${BLUE}Setting up VPLMN secrets...${NC}"
  create_or_replace_secret "vplmn" "sepp-ca" "--from-file=ca.crt=./open5gs_tls/ca.crt"
  create_or_replace_secret "vplmn" "sepp-n32c" "--from-file=key=./open5gs_tls/sepp-vplmn-n32c.key --from-file=cert=./open5gs_tls/sepp-vplmn-n32c.crt"
  create_or_replace_secret "vplmn" "sepp-n32f" "--from-file=key=./open5gs_tls/sepp-vplmn-n32f.key --from-file=cert=./open5gs_tls/sepp-vplmn-n32f.crt"
  
  # Create secrets for HPLMN
  echo -e "${BLUE}Setting up HPLMN secrets...${NC}"
  create_or_replace_secret "hplmn" "sepp-ca" "--from-file=ca.crt=./open5gs_tls/ca.crt"
  create_or_replace_secret "hplmn" "sepp-n32c" "--from-file=key=./open5gs_tls/sepp-hplmn-n32c.key --from-file=cert=./open5gs_tls/sepp-hplmn-n32c.crt"
  create_or_replace_secret "hplmn" "sepp-n32f" "--from-file=key=./open5gs_tls/sepp-hplmn-n32f.key --from-file=cert=./open5gs_tls/sepp-hplmn-n32f.crt"
  
  # Return to the base directory
  cd "$BASE_DIR"
  
  echo -e "${GREEN}Kubernetes secrets created successfully${NC}"
}

# Main function to run all steps
main() {
  echo -e "${BLUE}===============================================${NC}"
  echo -e "${BLUE}        Open5GS k8s-roaming Setup Script      ${NC}"
  echo -e "${BLUE}===============================================${NC}"
  
  # Ask for confirmation
  read -p "This script will install Docker, MicroK8s, and set up the Open5GS k8s-roaming environment. Continue? (y/n): " answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo -e "${RED}Setup aborted.${NC}"
    exit 0
  fi
  
  # Run each step
  install_docker
  install_microk8s
  configure_microk8s
  pull_images
  generate_certificates
  create_k8s_secrets
  
  echo -e "${BLUE}===============================================${NC}"
  echo -e "${GREEN}Setup completed! To deploy the components, run:${NC}"
  echo -e "${YELLOW}cd ${K8S_ROAMING_DIR}${NC}"
  echo -e "${YELLOW}# Deploy HPLMN first${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f hplmn/nrf/${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f hplmn/scp/${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f hplmn/udr/${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f hplmn/udm/${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f hplmn/ausf/${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f hplmn/sepp/${NC}"
  echo -e "${YELLOW}# Then deploy VPLMN${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f vplmn/nrf/${NC}"
  echo -e "${YELLOW}microk8s kubectl apply -f vplmn/scp/${NC}"
  echo -e "${YELLOW}# ...and so on for all components${NC}"
  echo -e "${BLUE}===============================================${NC}"
  
  echo -e "${YELLOW}NOTE: You might need to log out and back in for group changes to take effect before deploying.${NC}"
}

# Run the main function
main 