#!/bin/bash

TRUENAS_IP=192.168.1.169
POOL_NAME=tank

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

# Run Update

echo "Executing Updates."
# Update the package lists
apt update

# Upgrade installed packages
apt upgrade -y

# Perform a distribution upgrade (if available)
apt dist-upgrade -y

# Clean up unused packages and cached files
apt autoremove -y
apt autoclean
echo "Update Complete."

# Change directory to /tmp

cd /tmp

# Download the setup-repos.sh script
curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
echo "Downloading Webmin."

# Execute the setup-repos.sh script
sh setup-repos.sh

# Install Webmin
echo "Installing Webmin."
apt-get install webmin -y

# Install Docker
echo "Installing Docker."

apt-get install -y \
  ca-certificates \
  curl \
  gnupg

# Create directory for keyrings
install -m 0755 -d /etc/apt/keyrings

# Download and install Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set appropriate permissions for Docker GPG key
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository to apt sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
apt-get update

# Install Docker packages
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "Docker Installed."

# Install Portainer
echo "Installing Portainer."
docker volume create portainer_data

docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

echo "Portainer Installed."
echo "Done!"

# Add apps user and group
sudo groupadd -g 568 apps
sudo useradd -u 568 -g 568 -m -s /bin/bash apps
echo "User & Group apps created!"

#Mount TrueNAS NFS Share
sudo apt-get install nfs-common
echo "$TRUENAS_IP:/mnt/$POOL_NAME /mnt nfs defaults 0 0" | sudo tee -a /etc/fstab
sudo mount -a
echo "Mounted TrueNAS!"

#Build media directory structure
sudo mkdir -p /media/{downloads,movies,tv}
sudo mkdir /configs
sudo chown -R apps:apps /media/{downloads,movies,tv}
sudo chown -R apps:apps /configs

echo "Media directory structure created!"

#create docker network called group
sudo docker network create arr && echo "Docker network 'arr' created."

#add jq package
sudo apt install jq -y
echo "Added jq apt package!"
