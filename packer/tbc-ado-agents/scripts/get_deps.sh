#!/bin/bash
set -xe

# Script to install dependencies for Packer built image.

echo "Installing Docker"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install unzip ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world
sudo usermod -aG docker ubuntu

# Install AWSCLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Prepare ADO Agents

DIRS=("agent")

wget https://vstsagentpackage.azureedge.net/agent/3.245.0/vsts-agent-linux-x64-3.245.0.tar.gz

TEMP_DIR=$(mktemp -d)
TAR_FILE="vsts-agent-linux-x64-3.245.0.tar.gz"

tar zxvf "$TAR_FILE" -C "$TEMP_DIR"

for DIR in "${DIRS[@]}"; do 
    mkdir -p "$DIR"
    cp -r "$TEMP_DIR"/* "$DIR/"
    echo "${DIR} created"
done

rm -rf "${TEMP_DIR}" awscliv2.zip vsts-agent-linux-x64-3.245.0.tar.gz

echo "ADO Agents Prepped"

# SET PACKAGE VERSION VARIABLES
KUBE_VERSION="v1.31"
GOLANG_VERSION="go1.23.3"
HELM_VERSION="3.16.2-1"

# Update apt and install dependencies
sudo apt-get update && sudo apt-get upgrade --with-new-pkgs -y
sudo apt-get install -y git wget python3-pip jq apt-transport-https software-properties-common ca-certificates curl gnupg unzip --no-install-recommends

# Add Hashicorp apt repo
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Kubernetes
curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Add Helm apt repo
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Install Microsoft repo
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb

# Prepare to install Nodejs 23 
curl -fsSL https://deb.nodesource.com/setup_23.x -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh

# Install dependencies
sudo add-apt-repository universe
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get install python3.9 packer nodejs dotnet-sdk-8.0 terraform helm=${HELM_VERSION} powershell -y

# Install Helm S3 plugin
helm plugin install https://github.com/hypnoglow/helm-s3.git

# Install Go
cd /tmp && wget https://go.dev/dl/${GOLANG_VERSION}.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf /tmp/${GOLANG_VERSION}.linux-amd64.tar.gz
sudo chmod -R a+x /usr/local/go

cat << \EOF >> ~/.bash_profile
# Add .NET Core SDK tools and Go
export PATH="$PATH:/home/ubuntu/.dotnet/tools:/usr/local/go/bin"
EOF

dotnet tool install --global dotnet-ef

dotnet tool install -g microsoft.sqlpackage

# Clean up
sudo apt-get clean && rm -rf /var/lib/lists/*