#!/bin/bash
# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi



#variables for external mount point
TRUENAS_IP=
POOL_NAME=/

#discord variable
DISCORD_WEBHOOK=

#Add the wg0.conf wireguard file here

wireguard_conf="

[Interface]
# Device: 
PrivateKey = 
Address = 
DNS=1.1.1.1

[Peer]
PublicKey = 
AllowedIPs = 0.0.0.0/0
Endpoint = 
"

#docker container settings
TIMEZONE=America/New_York
PUID=568
PGID=568

# Set CONFIG_PATH 
  CONFIG_PATH=/configs


# Set MOVIES_PATH based on conditions
if [ -n "$TRUENAS_IP" ]; then
  MOVIES_PATH=/mnt/media/movies
else
  MOVIES_PATH=/media/movies
fi

# Set TV_PATH based on conditions
if [ -n "$TRUENAS_IP" ]; then
  TV_PATH=/mnt/media/tv
else
  TV_PATH=/media/tv
fi

# Set DOWNLOADS_PATH based on conditions
if [ -n "TRUENAS_IP" ]; then
  DOWNLOADS_PATH=/mnt/media/downloads
else
  DOWNLOADS_PATH=/media/downloads
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
yes | sh setup-repos.sh

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
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
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

# Mount TrueNAS NFS Share
if [ -n "$TRUENAS_IP" ]; then
  sudo apt-get install nfs-common -y
  echo "$TRUENAS_IP:/mnt$POOL_NAME /mnt nfs defaults 0 0" >> /etc/fstab
  sudo mount -a
  echo "Mounted TrueNAS!"
else
  echo "TRUENAS_IP variable is not defined. Skipping mounting of TrueNAS NFS share."
fi


#create docker network called group
sudo docker network create arr && echo "Docker network 'arr' created."


#Build media directory structure
    sudo mkdir -p /media/{downloads,movies,tv}
    sudo mkdir -p /configs/{emby,jellyseerr,prowlarr,qbit,radarr,recyclarr,sonarr,unpackerr}
    sudo chown -R apps:apps /media/{downloads,movies,tv}
    sudo chown -R apps:apps /configs /configs/{emby,jellyseerr,prowlarr,qbit,radarr,recyclarr,sonarr,unpackerr}
    sudo chmod -R 777 /media /configs


echo "Media directory structure created!"


#deploy arr stack containers

cat <<EOT > ./arrstack.yaml

version: "2.1"
services:
  emby:
    image: lscr.io/linuxserver/emby:latest
    container_name: emby
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ${CONFIG_PATH}/emby:/config
      - ${TV_PATH}:/media/tv
      - ${MOVIES_PATH}:/media/movies
    ports:
      - 8096:8096
      - 8920:8920 #optional
    networks:
      - arr
    restart: unless-stopped

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=${LOG_LEVEL:-info}
      - LOG_HTML=${LOG_HTML:-false}
      - CAPTCHA_SOLVER=${CAPTCHA_SOLVER:-none}
      - TZ=${TIMEZONE}
    ports:
      - "${PORT:-8191}:8191"
    restart: unless-stopped
    networks:
      - arr

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    environment:
      - LOG_LEVEL=debug
      - TZ=${TIMEZONE}
      - JELLYFIN_TYPE=emby
    ports:
      - 5055:5055
    volumes:
      - ${CONFIG_PATH}/jellyseerr:/app/config
    restart: unless-stopped
    networks:
      - arr

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ${CONFIG_PATH}/prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped
    networks:
      - arr

  qbittorrent:
    container_name: qbittorrent
    image: ghcr.io/hotio/qbittorrent
    ports:
      - "8080:8080"
      - "8118:8118"
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - UMASK=002
      - TZ=${TIMEZONE}
      - VPN_ENABLED=true
      - VPN_LAN_NETWORK=192.168.1.0/24
      - VPN_CONF=wg0
      - VPN_ADDITIONAL_PORTS
      - PRIVOXY_ENABLED=false
    volumes:
      - ${CONFIG_PATH}/qbit:/config
      - ${DOWNLOADS_PATH}:/media/downloads
    cap_add:
      - NET_ADMIN
    dns:
      - 1.1.1.1
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=1
    networks:
      - arr

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ${CONFIG_PATH}/radarr:/config
      - ${MOVIES_PATH}:/media/movies 
      - ${DOWNLOADS_PATH}:/media/downloads 
    ports:
      - 7878:7878
    restart: unless-stopped
    networks:
      - arr

  recyclarr:
    image: ghcr.io/recyclarr/recyclarr
    container_name: recyclarr
    user: 568:568
    volumes:
      - ${CONFIG_PATH}/recyclarr:/config
    environment:
      - TZ=${TIMEZONE}
    networks:
      - arr

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ${CONFIG_PATH}/sonarr:/config
      - ${TV_PATH}:/media/tv #optional
      - ${DOWNLOADS_PATH}:/media/downloads #optional
    ports:
      - 8989:8989
    restart: unless-stopped
    networks:
      - arr

  watchtower:
    image: containrrr/watchtower
    environment:
      - TZ=${TIMEZONE}
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
    restart: unless-stopped    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  unpackerr:
    container_name: unpackerr
    image: ghcr.io/hotio/unpackerr
    environment:
      - PUID=568
      - PGID=568
      - UMASK=002
      - TZ=${TIMEZONE}
    volumes:
      - ${CONFIG_PATH}/unpackerr:/config
    networks:
      - arr
    security_opt:
      - no-new-privileges:true

networks:
  arr:
    external: true



EOT

sudo docker-compose -f arrstack.yaml up -d
sleep 10



# Define qBittorrent parameters
qbittorrent_url="http://qbittorrent:8080"
qbittorrent_username="admin"
qbittorrent_password="adminadmin"


# Prowlarr API Key extract
# Check if the configuration file exists
if [ -f "$CONFIG_PATH/prowlarr/config.xml" ]; then
  # Extract the API key using grep and awk
  prowlarr_api_key=$(grep -oP '(?<=<ApiKey>).*?(?=</ApiKey>)' "$CONFIG_PATH/prowlarr/config.xml")

  if [ -n "$prowlarr_api_key" ]; then
    echo "Prowlarr API Key: $prowlarr_api_key"

    # Export the Prowlarr API key as a global variable
    export PROWLARR_API_KEY="$prowlarr_api_key"
    echo "Exported PROWLARR_API_KEY variable."
  else
    echo "API Key not found in the Prowlarr configuration file."
  fi
else
  echo "Prowlarr configuration file not found."
fi
sleep 10

# Sonarr API Key extract
# Check if the configuration file exists
if [ -f "$CONFIG_PATH/sonarr/config.xml" ]; then
  # Extract the API key using grep and awk
  sonarr_api_key=$(grep -oP '(?<=<ApiKey>).*?(?=</ApiKey>)' "$CONFIG_PATH/sonarr/config.xml")

  if [ -n "$sonarr_api_key" ]; then
    echo "Sonarr API Key: $sonarr_api_key"

    # Export the Sonarr API key as a global variable
    export SONARR_API_KEY="$sonarr_api_key"
    echo "Exported SONARR_API_KEY variable."
  else
    echo "Sonarr API Key not found in the configuration file."
  fi
else
  echo "Sonarr configuration file not found."
fi

sleep 5

# Radarr API Key extract
# Check if the configuration file exists
if [ -f "$CONFIG_PATH/radarr/config.xml" ]; then
  # Extract the API key using grep and awk
  radarr_api_key=$(grep -oP '(?<=<ApiKey>).*?(?=</ApiKey>)' "$CONFIG_PATH/radarr/config.xml")

  if [ -n "$radarr_api_key" ]; then
    echo "Radarr API Key: $radarr_api_key"

    # Export the Radarr API key as a global variable
    export RADARR_API_KEY="$radarr_api_key"
    echo "Exported RADARR_API_KEY variable."
  else
    echo "Radarr API Key not found in the configuration file."
  fi
else
  echo "Radarr configuration file not found."
fi


# Set the root folder for Sonarr
curl "http://localhost:8989/api/v3/rootFolder" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY" --data-raw '{"path":"/media/tv"}'

# Set the root folder for Radarr
curl "http://localhost:7878/api/v3/rootFolder" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY" --data-raw '{"path":"/media/movies"}'

# Add Sonarr to Prowlarr

curl "http://localhost:9696/api/v1/applications" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $PROWLARR_API_KEY" --data-raw '
{"syncLevel":"fullSync","name":"Sonarr","fields":[{"name":"prowlarrUrl","value":"http://prowlarr:9696"},{"name":"baseUrl","value":"http://sonarr:8989"},{"name":"apiKey","value":"'$SONARR_API_KEY'"},{"name":"syncCategories","value":[5000,5010,5020,5030,5040,5045,5050,5090]},{"name":"animeSyncCategories","value":[5070]},{"name":"syncAnimeStandardFormatSearch","value":false}],"implementationName":"Sonarr","implementation":"Sonarr","configContract":"SonarrSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported#sonarr","tags":[]}'


# Add Radarr to Prowlarr

curl "http://localhost:9696/api/v1/applications" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $PROWLARR_API_KEY" --data-raw '
{"syncLevel":"fullSync","name":"Radarr","fields":[{"name":"prowlarrUrl","value":"http://prowlarr:9696"},{"name":"baseUrl","value":"http://radarr:7878"},{"name":"apiKey","value":"'$RADARR_API_KEY'"},{"name":"syncCategories","value":[2000,2010,2020,2030,2040,2045,2050,2060,2070,2080,2090]}],"implementationName":"Radarr","implementation":"Radarr","configContract":"RadarrSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported#radarr","tags":[]}'

#clean up radarr profiles

curl "http://localhost:7878/api/v3/qualityprofile/1" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY"
curl "http://localhost:7878/api/v3/qualityprofile/6" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY"
curl "http://localhost:7878/api/v3/qualityprofile/3" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY"
curl "http://localhost:7878/api/v3/qualityprofile/2" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY"
curl "http://localhost:7878/api/v3/qualityprofile/4" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY" --data-raw '{{"name":"HD-1080p","upgradeAllowed":true,"cutoff":7,"items":[{"quality":{"id":0,"name":"Unknown","source":"unknown","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":24,"name":"WORKPRINT","source":"workprint","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":25,"name":"CAM","source":"cam","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":26,"name":"TELESYNC","source":"telesync","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":27,"name":"TELECINE","source":"telecine","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":29,"name":"REGIONAL","source":"dvd","resolution":480,"modifier":"regional"},"items":[],"allowed":false},{"quality":{"id":28,"name":"DVDSCR","source":"dvd","resolution":480,"modifier":"screener"},"items":[],"allowed":false},{"quality":{"id":1,"name":"SDTV","source":"tv","resolution":480,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":2,"name":"DVD","source":"dvd","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":23,"name":"DVD-R","source":"dvd","resolution":480,"modifier":"remux"},"items":[],"allowed":false},{"name":"WEB 480p","items":[{"quality":{"id":8,"name":"WEBDL-480p","source":"webdl","resolution":480,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":12,"name":"WEBRip-480p","source":"webrip","resolution":480,"modifier":"none"},"items":[],"allowed":false}],"allowed":false,"id":1000},{"quality":{"id":20,"name":"Bluray-480p","source":"bluray","resolution":480,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":21,"name":"Bluray-576p","source":"bluray","resolution":576,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":4,"name":"HDTV-720p","source":"tv","resolution":720,"modifier":"none"},"items":[],"allowed":false},{"name":"WEB 720p","items":[{"quality":{"id":5,"name":"WEBDL-720p","source":"webdl","resolution":720,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":14,"name":"WEBRip-720p","source":"webrip","resolution":720,"modifier":"none"},"items":[],"allowed":false}],"allowed":false,"id":1001},{"quality":{"id":6,"name":"Bluray-720p","source":"bluray","resolution":720,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":9,"name":"HDTV-1080p","source":"tv","resolution":1080,"modifier":"none"},"items":[],"allowed":true},{"name":"WEB 1080p","items":[{"quality":{"id":3,"name":"WEBDL-1080p","source":"webdl","resolution":1080,"modifier":"none"},"items":[],"allowed":true},{"quality":{"id":15,"name":"WEBRip-1080p","source":"webrip","resolution":1080,"modifier":"none"},"items":[],"allowed":true}],"allowed":true,"id":1002},{"quality":{"id":7,"name":"Bluray-1080p","source":"bluray","resolution":1080,"modifier":"none"},"items":[],"allowed":true},{"quality":{"id":30,"name":"Remux-1080p","source":"bluray","resolution":1080,"modifier":"remux"},"items":[],"allowed":false},{"quality":{"id":16,"name":"HDTV-2160p","source":"tv","resolution":2160,"modifier":"none"},"items":[],"allowed":false},{"name":"WEB 2160p","items":[{"quality":{"id":18,"name":"WEBDL-2160p","source":"webdl","resolution":2160,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":17,"name":"WEBRip-2160p","source":"webrip","resolution":2160,"modifier":"none"},"items":[],"allowed":false}],"allowed":false,"id":1003},{"quality":{"id":19,"name":"Bluray-2160p","source":"bluray","resolution":2160,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":31,"name":"Remux-2160p","source":"bluray","resolution":2160,"modifier":"remux"},"items":[],"allowed":false},{"quality":{"id":22,"name":"BR-DISK","source":"bluray","resolution":1080,"modifier":"brdisk"},"items":[],"allowed":false},{"quality":{"id":10,"name":"Raw-HD","source":"tv","resolution":1080,"modifier":"rawhd"},"items":[],"allowed":false}],"minFormatScore":0,"cutoffFormatScore":0,"formatItems":[],"language":{"id":1,"name":"English"},"id":4}
}'
curl "http://localhost:7878/api/v3/qualityprofile/5" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY" --data-raw '{{"name":"Ultra-HD","upgradeAllowed":true,"cutoff":19,"items":[{"quality":{"id":0,"name":"Unknown","source":"unknown","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":24,"name":"WORKPRINT","source":"workprint","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":25,"name":"CAM","source":"cam","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":26,"name":"TELESYNC","source":"telesync","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":27,"name":"TELECINE","source":"telecine","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":29,"name":"REGIONAL","source":"dvd","resolution":480,"modifier":"regional"},"items":[],"allowed":false},{"quality":{"id":28,"name":"DVDSCR","source":"dvd","resolution":480,"modifier":"screener"},"items":[],"allowed":false},{"quality":{"id":1,"name":"SDTV","source":"tv","resolution":480,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":2,"name":"DVD","source":"dvd","resolution":0,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":23,"name":"DVD-R","source":"dvd","resolution":480,"modifier":"remux"},"items":[],"allowed":false},{"name":"WEB 480p","items":[{"quality":{"id":8,"name":"WEBDL-480p","source":"webdl","resolution":480,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":12,"name":"WEBRip-480p","source":"webrip","resolution":480,"modifier":"none"},"items":[],"allowed":false}],"allowed":false,"id":1000},{"quality":{"id":20,"name":"Bluray-480p","source":"bluray","resolution":480,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":21,"name":"Bluray-576p","source":"bluray","resolution":576,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":4,"name":"HDTV-720p","source":"tv","resolution":720,"modifier":"none"},"items":[],"allowed":false},{"name":"WEB 720p","items":[{"quality":{"id":5,"name":"WEBDL-720p","source":"webdl","resolution":720,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":14,"name":"WEBRip-720p","source":"webrip","resolution":720,"modifier":"none"},"items":[],"allowed":false}],"allowed":false,"id":1001},{"quality":{"id":6,"name":"Bluray-720p","source":"bluray","resolution":720,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":9,"name":"HDTV-1080p","source":"tv","resolution":1080,"modifier":"none"},"items":[],"allowed":false},{"name":"WEB 1080p","items":[{"quality":{"id":3,"name":"WEBDL-1080p","source":"webdl","resolution":1080,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":15,"name":"WEBRip-1080p","source":"webrip","resolution":1080,"modifier":"none"},"items":[],"allowed":false}],"allowed":false,"id":1002},{"quality":{"id":7,"name":"Bluray-1080p","source":"bluray","resolution":1080,"modifier":"none"},"items":[],"allowed":false},{"quality":{"id":30,"name":"Remux-1080p","source":"bluray","resolution":1080,"modifier":"remux"},"items":[],"allowed":false},{"quality":{"id":16,"name":"HDTV-2160p","source":"tv","resolution":2160,"modifier":"none"},"items":[],"allowed":true},{"name":"WEB 2160p","items":[{"quality":{"id":18,"name":"WEBDL-2160p","source":"webdl","resolution":2160,"modifier":"none"},"items":[],"allowed":true},{"quality":{"id":17,"name":"WEBRip-2160p","source":"webrip","resolution":2160,"modifier":"none"},"items":[],"allowed":true}],"allowed":true,"id":1003},{"quality":{"id":19,"name":"Bluray-2160p","source":"bluray","resolution":2160,"modifier":"none"},"items":[],"allowed":true},{"quality":{"id":31,"name":"Remux-2160p","source":"bluray","resolution":2160,"modifier":"remux"},"items":[],"allowed":false},{"quality":{"id":22,"name":"BR-DISK","source":"bluray","resolution":1080,"modifier":"brdisk"},"items":[],"allowed":false},{"quality":{"id":10,"name":"Raw-HD","source":"tv","resolution":1080,"modifier":"rawhd"},"items":[],"allowed":false}],"minFormatScore":0,"cutoffFormatScore":0,"formatItems":[],"language":{"id":1,"name":"English"},"id":5}
}'


#clean up sonarr profiles

curl "http://localhost:8989/api/v3/qualityprofile/1" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY"
curl "http://localhost:8989/api/v3/qualityprofile/6" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY"
curl "http://localhost:8989/api/v3/qualityprofile/3" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY"
curl "http://localhost:8989/api/v3/qualityprofile/2" -X DELETE -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY"
curl "http://localhost:8989/api/v3/qualityprofile/4" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY" --data-raw '{"name":"HD-1080p","upgradeAllowed":true,"cutoff":7,"items":[{"quality":{"id":0,"name":"Unknown","source":"unknown","resolution":0},"items":[],"allowed":false},{"quality":{"id":1,"name":"SDTV","source":"television","resolution":480},"items":[],"allowed":false},{"name":"WEB 480p","items":[{"quality":{"id":12,"name":"WEBRip-480p","source":"webRip","resolution":480},"items":[],"allowed":false},{"quality":{"id":8,"name":"WEBDL-480p","source":"web","resolution":480},"items":[],"allowed":false}],"allowed":false,"id":1000},{"quality":{"id":2,"name":"DVD","source":"dvd","resolution":480},"items":[],"allowed":false},{"quality":{"id":13,"name":"Bluray-480p","source":"bluray","resolution":480},"items":[],"allowed":false},{"quality":{"id":4,"name":"HDTV-720p","source":"television","resolution":720},"items":[],"allowed":false},{"quality":{"id":9,"name":"HDTV-1080p","source":"television","resolution":1080},"items":[],"allowed":true},{"quality":{"id":10,"name":"Raw-HD","source":"televisionRaw","resolution":1080},"items":[],"allowed":false},{"name":"WEB 720p","items":[{"quality":{"id":14,"name":"WEBRip-720p","source":"webRip","resolution":720},"items":[],"allowed":false},{"quality":{"id":5,"name":"WEBDL-720p","source":"web","resolution":720},"items":[],"allowed":false}],"allowed":false,"id":1001},{"quality":{"id":6,"name":"Bluray-720p","source":"bluray","resolution":720},"items":[],"allowed":false},{"name":"WEB 1080p","items":[{"quality":{"id":15,"name":"WEBRip-1080p","source":"webRip","resolution":1080},"items":[],"allowed":true},{"quality":{"id":3,"name":"WEBDL-1080p","source":"web","resolution":1080},"items":[],"allowed":true}],"allowed":true,"id":1002},{"quality":{"id":7,"name":"Bluray-1080p","source":"bluray","resolution":1080},"items":[],"allowed":true},{"quality":{"id":20,"name":"Bluray-1080p Remux","source":"blurayRaw","resolution":1080},"items":[],"allowed":false},{"quality":{"id":16,"name":"HDTV-2160p","source":"television","resolution":2160},"items":[],"allowed":false},{"name":"WEB 2160p","items":[{"quality":{"id":17,"name":"WEBRip-2160p","source":"webRip","resolution":2160},"items":[],"allowed":false},{"quality":{"id":18,"name":"WEBDL-2160p","source":"web","resolution":2160},"items":[],"allowed":false}],"allowed":false,"id":1003},{"quality":{"id":19,"name":"Bluray-2160p","source":"bluray","resolution":2160},"items":[],"allowed":false},{"quality":{"id":21,"name":"Bluray-2160p Remux","source":"blurayRaw","resolution":2160},"items":[],"allowed":false}],"id":4}'
curl "http://localhost:8989/api/v3/qualityprofile/5" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY" --data-raw '{"name":"HD-1080p","upgradeAllowed":true,"cutoff":7,"items":[{"quality":{"id":0,"name":"Unknown","source":"unknown","resolution":0},"items":[],"allowed":false},{"quality":{"id":1,"name":"SDTV","source":"television","resolution":480},"items":[],"allowed":false},{"name":"WEB 480p","items":[{"quality":{"id":12,"name":"WEBRip-480p","source":"webRip","resolution":480},"items":[],"allowed":false},{"quality":{"id":8,"name":"WEBDL-480p","source":"web","resolution":480},"items":[],"allowed":false}],"allowed":false,"id":1000},{"quality":{"id":2,"name":"DVD","source":"dvd","resolution":480},"items":[],"allowed":false},{"quality":{"id":13,"name":"Bluray-480p","source":"bluray","resolution":480},"items":[],"allowed":false},{"quality":{"id":4,"name":"HDTV-720p","source":"television","resolution":720},"items":[],"allowed":false},{"quality":{"id":9,"name":"HDTV-1080p","source":"television","resolution":1080},"items":[],"allowed":true},{"quality":{"id":10,"name":"Raw-HD","source":"televisionRaw","resolution":1080},"items":[],"allowed":false},{"name":"WEB 720p","items":[{"quality":{"id":14,"name":"WEBRip-720p","source":"webRip","resolution":720},"items":[],"allowed":false},{"quality":{"id":5,"name":"WEBDL-720p","source":"web","resolution":720},"items":[],"allowed":false}],"allowed":false,"id":1001},{"quality":{"id":6,"name":"Bluray-720p","source":"bluray","resolution":720},"items":[],"allowed":false},{"name":"WEB 1080p","items":[{"quality":{"id":15,"name":"WEBRip-1080p","source":"webRip","resolution":1080},"items":[],"allowed":true},{"quality":{"id":3,"name":"WEBDL-1080p","source":"web","resolution":1080},"items":[],"allowed":true}],"allowed":true,"id":1002},{"quality":{"id":7,"name":"Bluray-1080p","source":"bluray","resolution":1080},"items":[],"allowed":true},{"quality":{"id":20,"name":"Bluray-1080p Remux","source":"blurayRaw","resolution":1080},"items":[],"allowed":false},{"quality":{"id":16,"name":"HDTV-2160p","source":"television","resolution":2160},"items":[],"allowed":false},{"name":"WEB 2160p","items":[{"quality":{"id":17,"name":"WEBRip-2160p","source":"webRip","resolution":2160},"items":[],"allowed":false},{"quality":{"id":18,"name":"WEBDL-2160p","source":"web","resolution":2160},"items":[],"allowed":false}],"allowed":false,"id":1003},{"quality":{"id":19,"name":"Bluray-2160p","source":"bluray","resolution":2160},"items":[],"allowed":false},{"quality":{"id":21,"name":"Bluray-2160p Remux","source":"blurayRaw","resolution":2160},"items":[],"allowed":false}],"id":4}'

#add webhooks

curl "http://localhost:8989/api/v3/notification" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY" --data-raw '{"onGrab":true,"onDownload":true,"onUpgrade":true,"onRename":true,"onSeriesDelete":true,"onEpisodeFileDelete":true,"onEpisodeFileDeleteForUpgrade":true,"onHealthIssue":false,"onApplicationUpdate":true,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnSeriesDelete":true,"supportsOnEpisodeFileDelete":true,"supportsOnEpisodeFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnApplicationUpdate":true,"includeHealthWarnings":false,"name":"Discord","fields":[{"name":"webHookUrl","value":"'"$DISCORD_WEBHOOK"'"},{"name":"username","value":"sonarr"},{"name":"avatar"},{"name":"author"},{"name":"grabFields","value":[0,1,2,3,5,6,7,8,9]},{"name":"importFields","value":[0,1,2,3,4,6,7,8,9,10,11,12]}],"implementationName":"Discord","implementation":"Discord","configContract":"DiscordSettings","infoLink":"https://wiki.servarr.com/sonarr/supported#discord","tags":[]}'
curl "http://localhost:7878/api/v3/notification" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY" --data-raw '{"onGrab":true,"onDownload":true,"onUpgrade":true,"onRename":true,"onMovieAdded":true,"onMovieDelete":true,"onMovieFileDelete":true,"onMovieFileDeleteForUpgrade":true,"onHealthIssue":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":true,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnMovieAdded":true,"supportsOnMovieDelete":true,"supportsOnMovieFileDelete":true,"supportsOnMovieFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":true,"includeHealthWarnings":false,"name":"Discord","fields":[{"name":"webHookUrl","value":"'"$DISCORD_WEBHOOK"'"},{"name":"username","value":"radarr"},{"name":"avatar"},{"name":"author"},{"name":"grabFields","value":[0,1,2,3,4,5,6,7,8,9,10,11,12]},{"name":"importFields","value":[0,1,2,3,4,6,7,8,9,10,11,12]},{"name":"manualInteractionFields","value":[0,1,2,3,5,6,7,8,9]}],"implementationName":"Discord","implementation":"Discord","configContract":"DiscordSettings","infoLink":"https://wiki.servarr.com/radarr/supported#discord","tags":[]}'
curl "http://localhost:7878/api/v1/notification" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $PROWLARR_API_KEY" --data-raw '{"onGrab":true,"onHealthIssue":false,"onHealthRestored":false,"onApplicationUpdate":true,"supportsOnGrab":true,"includeManualGrabs":false,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"includeHealthWarnings":false,"supportsOnApplicationUpdate":true,"name":"Discord","fields":[{"name":"webHookUrl","value":"'"$DISCORD_WEBHOOK"'"},{"name":"username","value":"prowlarr"},{"name":"avatar"},{"name":"author"},{"name":"grabFields","value":[0,1,2,3,5,6,7,8,9]}],"implementationName":"Discord","implementation":"Discord","configContract":"DiscordSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported#discord","tags":[]}'





#Update Qbit config

sudo docker stop qbittorrent
new_config="
[AutoRun]
OnTorrentAdded\Enabled=false
OnTorrentAdded\Program=
enabled=false
program=

[BitTorrent]
Session\DefaultSavePath=/media/downloads
Session\ExcludedFileNames=
Session\IgnoreLimitsOnLAN=true
Session\Interface=wg0
Session\InterfaceAddress=0.0.0.0
Session\InterfaceName=wg0
Session\MaxConnections=-1
Session\MaxConnectionsPerTorrent=-1
Session\MaxUploads=-1
Session\MaxUploadsPerTorrent=-1
Session\Port=57132
Session\QueueingSystemEnabled=false
Session\uTPRateLimited=false

[Core]
AutoDeleteAddedTorrentFile=Never

[Meta]
MigrationVersion=4

[Network]
Proxy\OnlyForTorrents=false

[Preferences]
Advanced\RecheckOnCompletion=false
Advanced\trackerPort=9000
Advanced\trackerPortForwarding=false
Connection\ResolvePeerCountries=true
Downloads\SavePath=/config/downloads/
Downloads\TempPath=/config/downloads/temp/
DynDNS\DomainName=changeme.dyndns.org
DynDNS\Enabled=false
DynDNS\Password=
DynDNS\Service=DynDNS
DynDNS\Username=
General\Locale=en
MailNotification\email=
MailNotification\enabled=false
MailNotification\password=
MailNotification\req_auth=true
MailNotification\req_ssl=false
MailNotification\sender=qBittorrent_notification@example.com
MailNotification\smtp_server=smtp.changeme.com
MailNotification\username=
Scheduler\days=EveryDay
Scheduler\end_time=@Variant(\0\0\0\xf\xff\xff\xff\xff)
Scheduler\start_time=@Variant(\0\0\0\xf\x1\xb7t\0)
WebUI\Address=*
WebUI\AlternativeUIEnabled=true
WebUI\AuthSubnetWhitelist=192.168.1.0/24
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=true
WebUI\ClickjackingProtection=true
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\CertificatePath=
WebUI\HTTPS\Enabled=false
WebUI\HTTPS\KeyPath=
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=8080
WebUI\ReverseProxySupportEnabled=false
WebUI\RootFolder=/app/vuetorrent
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=
WebUI\UseUPnP=false
WebUI\Username=admin

[RSS]
AutoDownloader\DownloadRepacks=true
"

echo "$new_config" > "$CONFIG_PATH/qbit/config/qBittorrent.conf"
echo "$wireguard_conf" > "$CONFIG_PATH/qbit/wireguard/wg0.conf"
sudo docker start qbittorrent
sleep 3


# Add qBittorrent as a download client to Sonarr

curl "http://localhost:8989/api/v3/downloadclient" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $SONARR_API_KEY" --data-raw '
{"enable":true,"protocol":"torrent","priority":1,"removeCompletedDownloads":true,"removeFailedDownloads":true,"name":"qbittorrent","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"urlBase"},{"name":"username","value":"admin"},{"name":"password","value":"adminadmin"},{"name":"tvCategory","value":"tv-sonarr"},{"name":"tvImportedCategory"},{"name":"recentTvPriority","value":0},{"name":"olderTvPriority","value":0},{"name":"initialState","value":0},{"name":"sequentialOrder","value":false},{"name":"firstAndLast","value":false}],"implementationName":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","infoLink":"https://wiki.servarr.com/sonarr/supported#qbittorrent","tags":[]}'

# Add qBittorrent as a download client to Radarr

curl "http://localhost:7878/api/v3/downloadclient" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $RADARR_API_KEY" --data-raw '
{"enable":true,"protocol":"torrent","priority":1,"removeCompletedDownloads":true,"removeFailedDownloads":true,"name":"qbittorrent","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"urlBase"},{"name":"username","value":"admin"},{"name":"password","value":"adminadmin"},{"name":"movieCategory","value":"radarr"},{"name":"movieImportedCategory"},{"name":"recentMoviePriority","value":0},{"name":"olderMoviePriority","value":0},{"name":"initialState","value":0},{"name":"sequentialOrder","value":false},{"name":"firstAndLast","value":false}],"implementationName":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","infoLink":"https://wiki.servarr.com/radarr/supported#qbittorrent","tags":[]}'


# Add qBittorrent as a download client to Prowlarr

curl "http://localhost:9696/api/v1/downloadclient" -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Api-Key: $PROWLARR_API_KEY" --data-raw '
{"enable":true,"protocol":"torrent","priority":1,"categories":[],"supportsCategories":true,"name":"QBittorrent","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"urlBase"},{"name":"username","value":"admin"},{"name":"password","value":"adminadmin"},{"name":"category","value":"prowlarr"},{"name":"priority","value":0},{"name":"initialState","value":0},{"name":"sequentialOrder","value":false},{"name":"firstAndLast","value":false}],"implementationName":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported#qbittorrent","tags":[]}'



#configure unpackerr

sudo docker stop unpackerr

cat <<EOT > "/configs/unpackerr/unpackerr.conf"
##      Unpackerr Example Configuration File      ##
## The following values are application defaults. ##
## Environment Variables may override all values. ##
####################################################

# [true/false] Turn on debug messages in the output. Do not wrap this in quotes.
# Recommend trying this so you know what it looks like. I personally leave it on.
debug = false

# Disable writing messages to stdout. This silences the app. You should set a log
# file below if you set this to true. Recommended when starting with systemctl.
quiet = false

# Setting activity to true will silence all app queue log lines with only zeros.
# Set this to true when you want less log spam.
activity = false

# The application queue data is logged on an interval. Adjust that interval with this setting.
# Default is a minute. 2m, 5m, 10m, 30m, 1h are also perfectly acceptable.
log_queues = "1m"

# Write messages to a log file. This is the same data that is normally output to stdout.
# This setting is great for Docker users that want to export their logs to a file.
# The alternative is to use syslog to log the output of the application to a file.
# Default is no log file; this is unset. log_files=0 turns off auto-rotation.
# Default files is 10 and size(mb) is 10 Megabytes; both doubled if debug is true.
#log_file = '/downloads/unpackerr.log'
log_files = 10
log_file_mb = 10

# How often to poll sonarr and radarr.
# Recommend 1m-5m. Uses Go Duration.
interval = "1m"

# How long an item must be queued (download complete) before extraction will start.
# One minute is the historic default and works well. Set higher if your downloads
# take longer to finalize (or transfer locally). Uses Go Duration.
start_delay = "1m"

# How long to wait before removing the history for a failed extraction.
# Once the history is deleted the item will be recognized as new and
# extraction will start again. Uses Go Duration.
retry_delay = "5m"

# How many files may be extracted in parallel. 1 works fine.
# Do not wrap the number in quotes. Raise this only if you have fast disks and CPU.
parallel = 1

# Use these configurations to control the file modes used for newly extracted
# files and folders. Recommend 0644/0755 or 0666/0777.
file_mode = "0644"
dir_mode = "0755"

[webserver]
## The web server currently only supports metrics; set this to true if you wish to use it.
  metrics = false
## This may be set to a port or an ip:port to bind a specific IP. 0.0.0.0 binds ALL IPs.
  listen_addr = "0.0.0.0:5656"
## Recommend setting a log file for HTTP requests. Otherwise, they go with other logs.
  log_file = ""
## This app automatically rotates logs. Set these to the size and number to keep.
  log_files = 10
  log_file_mb = 10
## Set both of these to valid file paths to enable HTTPS/TLS.
  ssl_cert_file = ""
  ssl_key_file = ""
## Base URL from which to serve content.
  urlbase = "/"
## Upstreams should be set to the IP or CIDR of your trusted upstream proxy.
## Setting this correctly allows X-Forwarded-For to be used in logs.
## In the future it may control auth proxy trust. Must be a list of strings.
  upstreams = [ ] # example: upstreams = [ "127.0.0.1/32", "10.1.2.0/24" ]

##-Notes-#######-READ THIS!!!-##################################################
## The following sections can be repeated if you have more than one Sonarr,   ##
## Radarr or Lidarr, Readarr, Folder, Webhook, or Command Hook.               ##
## You MUST uncomment the [[header]] and api_key at a minimum for Starr apps. ##
##                ALL LINES BEGINNING WITH A HASH # ARE IGNORED               ##
##            REMOVE THE HASH # FROM CONFIG LINES YOU WANT TO CHANGE          ##
################################################################################

[[sonarr]]
 url = "http://sonarr:8989"
 api_key = "$SONARR_API_KEY"
## File system path where downloaded Sonarr items are located.
 paths = ['/media/downloads']
## Default protocols is torrent. Alternative: "torrent,usenet"
 protocols = "torrent"
## How long to wait for a reply from the backend.
 timeout = "10s"
## How long to wait after import before deleting the extracted items.
 delete_delay = "5m"


[[radarr]]
 url = "http://radarr:7878"
 api_key = "$RADARR_API_KEY"
## File system path where downloaded Radarr items are located.
 paths = ['/media/downloads']
## Default protocols is torrents. Alternative: "torrent,usenet"
 protocols = "torrent"
## How long to wait for a reply from the backend.
 timeout = "10s"
## How long to wait after import before deleting the extracted items.
 delete_delay = "5m"



################
### Webhooks ###
################
# Sends a webhook when an extraction queues, starts, finishes, and/or is deleted.
# Created to integrate with notifiarr.com.
# Also works natively with Discord.com, Telegram.org, and Slack.com webhooks.
# Can possibly be used with other services by providing a custom template_path.
###### Don't forget to uncomment [[webhook]] and url at a minimum !!!!
[[webhook]]
 url    = "$DISCORD_WEBHOOK"
 name   = ""    # Set this to hide the URL in logs.
 silent = false # do not log success (less log spam)
 events = [0]   # list of event ids to include, 0 == all.
## Advanced Optional Webhook Configuration
# nickname      = ""    # Used in Discord and Slack templates as bot name, in Telegram as chat_id.
# channel       = ""    # Also passed into templates. Used in Slack templates for destination channel.
# exclude       = []    # list of apps to exclude, ie. ["radarr", "lidarr"]
# template_path = ""    # Override internal webhook template for discord.com or other hooks.
 template      = "discord"    # Override automatic template detection. Values: notifiarr, discord, telegram, gotify, pushover, slack
# ignore_ssl    = false # Set this to true to ignore the SSL certificate on the server.
# timeout       = "10s" # You can adjust how long to wait for a server response.
# content_type  = "application/json" # If your custom template uses another MIME type, set this.


EOT

sudo docker start unpackerr




#recyclarr setup

sudo docker exec recyclarr recyclarr config create
#sudo -u apps chmod 777 $CONFIG_PATH/recyclarr/recyclarr.yml

cat <<EOF > $CONFIG_PATH/recyclarr/recyclarr.yml
# Configuration specific to Sonarr
sonarr:
  series:
    # Set the URL/API Key to your actual instance
    base_url: http://sonarr:8989
    api_key: $SONARR_API_KEY

    # Quality definitions from the guide to sync to Sonarr. Choices: series, anime
    quality_definition:
      type: series

    # Release profiles from the guide to sync to Sonarr v3 (Sonarr v4 does not use this!)
    # Use `recyclarr list release-profiles` for values you can put here.
    # https://trash-guides.info/Sonarr/Sonarr-Release-Profile-RegEx/
    release_profiles:
      # Series
      - trash_ids:
          - EBC725268D687D588A20CBC5F97E538B # Low Quality Groups
          - 1B018E0C53EC825085DD911102E2CA36 # Release Sources (Streaming Service)
          - 71899E6C303A07AF0E4746EFF9873532 # P2P Groups + Repack/Proper
          - 76e060895c5b8a765c310933da0a5357 # Optionals
      # Anime (Uncomment below if you want it)
      #- trash_ids:
      #    - d428eda85af1df8904b4bbe4fc2f537c # Anime - First release profile
      #    - 6cd9e10bb5bb4c63d2d7cd3279924c7b # Anime - Second release profile

# Configuration specific to Radarr.
radarr:
 uhd-bluray-web:
    base_url: http://radarr:7878
    api_key: $RADARR_API_KEY

    include:
     # Comment out any of the following includes to disable them
     - template: radarr-quality-definition-movie
     - template: radarr-quality-profile-uhd-bluray-web
     - template: radarr-custom-formats-uhd-bluray-web
     - template: radarr-quality-definition-movie
     - template: radarr-quality-profile-hd-bluray-web
     - template: radarr-custom-formats-hd-bluray-web

# Custom Formats: https://recyclarr.dev/wiki/yaml/config-reference/custom-formats/
    custom_formats:
     # Audio
     - trash_ids:
         # Uncomment the next section to enable Advanced Audio Formats
         # - 496f355514737f7d83bf7aa4d24f8169 # TrueHD Atmos
         # - 2f22d89048b01681dde8afe203bf2e95 # DTS X
         # - 417804f7f2c4308c1f4c5d380d4c4475 # ATMOS (undefined)
         # - 1af239278386be2919e1bcee0bde047e # DD+ ATMOS
         # - 3cafb66171b47f226146a0770576870f # TrueHD
         # - dcf3ec6938fa32445f590a4da84256cd # DTS-HD MA
         # - a570d4a0e56a2874b64e5bfa55202a1b # FLAC
         # - e7c2fcae07cbada050a0af3357491d7b # PCM
         # - 8e109e50e0a0b83a5098b056e13bf6db # DTS-HD HRA
         # - 185f1dd7264c4562b9022d963ac37424 # DD+
         # - f9f847ac70a0af62ea4a08280b859636 # DTS-ES
         # - 1c1a4c5e823891c75bc50380a6866f73 # DTS
         # - 240770601cc226190c367ef59aba7463 # AAC
         # - c2998bd0d90ed5621d8df281e839436e # DD
       quality_profiles:
         - name: UHD Bluray + WEB

     # Movie Versions
     - trash_ids:
         - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
       quality_profiles:
         - name: UHD Bluray + WEB
           # score: 0 # Uncomment this line to disable prioritised IMAX Enhanced releases

     # Optional
     - trash_ids:
         # Comment out the next line if you and all of your users' setups are fully DV compatible
         - 923b6abef9b17f937fab56cfcf89e1f1 # DV (WEBDL)
         # HDR10Plus Boost - Uncomment the next line if any of your devices DO support HDR10+
         # - b17886cb4158d9fea189859409975758 # HDR10Plus Boost
       quality_profiles:
         - name: UHD Bluray + WEB

     - trash_ids:
         - 9c38ebb7384dada637be8899efa68e6f # SDR
       quality_profiles:
         - name: UHD Bluray + WEB
           # score: 0 # Uncomment this line to allow SDR releases

     - trash_ids:
         - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
       quality_profiles:
         - name: HD Bluray + WEB
           # score: 0 # Uncomment this line to disable prioritised IMAX Enhanced releases
EOF

sleep 1
sudo docker exec recyclarr recyclarr sync radarr
sleep 5
sudo docker exec recyclarr recyclarr sync sonarr
sleep 5

#api key output
echo "Your Sonarr API Key is $sonarr_api_key"
echo "Your Radarr API Key is $radarr_api_key"
