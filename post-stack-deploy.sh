#!/bin/bash
# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi


#variables

DISCORD_WEBHOOK=
CONFIG_PATH=/configs



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

# Check if the Prowlarr configuration file exists
if [ -f "$CONFIG_PATH/prowlarr/config.xml" ]; then
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
sleep 5

# Check if the Sonarr configuration file exists
if [ -f "$CONFIG_PATH/sonarr/config.xml" ]; then
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

# Check if the Radarr configuration file exists
if [ -f "$CONFIG_PATH/radarr/config.xml" ]; then
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

cat <<EOT > $CONFIG_PATH/unpackerr/unpackerr.conf
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

sudo chown -R apps:apps $CONFIG_PATH/recyclarr

sudo docker exec recyclarr recyclarr config create


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
    # Use 'recyclarr list release-profiles' for values you can put here.
    # https://trash-guides.info/Sonarr/Sonarr-Release-Profile-RegEx/
    release_profiles:
      # Series
      - trash_ids:
          - 76e060895c5b8a765c310933da0a5357 # Optionals
          - 71899E6C303A07AF0E4746EFF9873532 # P2P Groups + Repack/Proper
          - d428eda85af1df8904b4bbe4fc2f537c # Anime - First release profile
          - EBC725268D687D588A20CBC5F97E538B # Low Quality Groups
          - 1B018E0C53EC825085DD911102E2CA36 # Release Sources (Streaming Service)
          - 6cd9e10bb5bb4c63d2d7cd3279924c7b # Anime - Second release profile

# Configuration specific to Radarr.
radarr:
  movies:
    # Set the URL/API Key to your actual instance
    base_url: http://radarr:7878
    api_key: $RADARR_API_KEY

    # Which quality definition in the guide to sync to Radarr. Only choice right now is 'movie'
    quality_definition:
      type: movie

    # Set to 'true' to automatically remove custom formats from Radarr when they are removed from
    # the guide or your configuration. This will NEVER delete custom formats you manually created!
    delete_old_custom_formats: false

    custom_formats:
      # A list of custom formats to sync to Radarr.
      # Use 'recyclarr list custom-formats radarr' for values you can put here.
      # https://trash-guides.info/Radarr/Radarr-collection-of-custom-formats/
      - trash_ids:
          # [No Category]
          - 820b09bb9acbfde9c35c71e0e565dad8 # 1080p
          - fb392fb0d61a010ae38e49ceaa24a1ef # 2160p
          - b2be17d608fc88818940cd1833b0b24c # 720p
          - 5153ec7413d9dae44e24275589b5e944 # BHDStudio
          - 0a3f082873eb454bde444150b70253cc # Extras
          - e098247bc6652dd88c76644b275260ed # FLUX
          - ff5bc9e8ce91d46c997ca3ac6994d6f8 # FraMeSToR
          - 8cd3ac70db7ac318cf9a0e01333940a4 # SiC

          # Anime
          - fb3ccc5d5cc8f77c9055d4cb4561dded # Anime BD Tier 01 (Top SeaDex Muxers)
          - 66926c8fa9312bc74ab71bf69aae4f4a # Anime BD Tier 02 (SeaDex Muxers)
          - fa857662bad28d5ff21a6e611869a0ff # Anime BD Tier 03 (SeaDex Muxers)
          - f262f1299d99b1a2263375e8fa2ddbb3 # Anime BD Tier 04 (SeaDex Muxers)
          - ca864ed93c7b431150cc6748dc34875d # Anime BD Tier 05 (Remuxes)
          - 9dce189b960fddf47891b7484ee886ca # Anime BD Tier 06 (FanSubs)
          - 1ef101b3a82646b40e0cab7fc92cd896 # Anime BD Tier 07 (P2P/Scene)
          - 6115ccd6640b978234cc47f2c1f2cadc # Anime BD Tier 08 (Mini Encodes)
          - b0fdc5897f68c9a68c70c25169f77447 # Anime LQ Groups
          - 06b6542a47037d1e33b15aa3677c2365 # Anime Raws
          - 8167cffba4febfb9a6988ef24f274e7e # Anime Web Tier 01 (Muxers)
          - 8526c54e36b4962d340fce52ef030e76 # Anime Web Tier 02 (Top FanSubs)
          - de41e72708d2c856fa261094c85e965d # Anime Web Tier 03 (Official Subs)
          - 9edaeee9ea3bcd585da9b7c0ac3fc54f # Anime Web Tier 04 (Official Subs)
          - 22d953bbe897857b517928f3652b8dd3 # Anime Web Tier 05 (FanSubs)
          - a786fbc0eae05afe3bb51aee3c83a9d4 # Anime Web Tier 06 (FanSubs)
          - 60f6d50cbd3cfc3e9a8c00e3a30c3114 # VRV
          - c259005cbaeb5ab44c06eddb4751e70c # v0
          - 5f400539421b8fcf71d51e6384434573 # v1
          - 3df5e6dfef4b09bb6002f732bed5b774 # v2
          - db92c27ba606996b146b57fbe6d09186 # v3
          - d4e5e842fad129a3c097bdb2d20d31a0 # v4

          # Anime Optional
          - a5d148168c4506b55cf53984107c396e # 10bit
          - 4a3b087eea2ce012fcc1ce319259a3be # Anime Dual Audio
          - b23eae459cc960816f2d6ba84af45055 # Dubs Only
          - 064af5f084a0a24458cc8ecd3220f93f # Uncensored

          # Audio Advanced #1
          - 417804f7f2c4308c1f4c5d380d4c4475 # ATMOS (undefined)
          - 185f1dd7264c4562b9022d963ac37424 # DD+
          - 1af239278386be2919e1bcee0bde047e # DD+ ATMOS
          - 1c1a4c5e823891c75bc50380a6866f73 # DTS
          - 2f22d89048b01681dde8afe203bf2e95 # DTS X
          - f9f847ac70a0af62ea4a08280b859636 # DTS-ES
          - dcf3ec6938fa32445f590a4da84256cd # DTS-HD MA
          - 3cafb66171b47f226146a0770576870f # TrueHD
          - 496f355514737f7d83bf7aa4d24f8169 # TrueHD ATMOS

          # Audio Advanced #2
          - 240770601cc226190c367ef59aba7463 # AAC
          - c2998bd0d90ed5621d8df281e839436e # DD
          - 8e109e50e0a0b83a5098b056e13bf6db # DTS-HD HRA
          - a570d4a0e56a2874b64e5bfa55202a1b # FLAC
          - 6ba9033150e7896bdc9ec4b44f2b230f # MP3
          - a061e2e700f81932daf888599f8a8273 # Opus
          - e7c2fcae07cbada050a0af3357491d7b # PCM

          # Audio Channels
          - b124be9b146540f8e62f98fe32e49a2a # 1.0 Mono
          - 89dac1be53d5268a7e10a19d3c896826 # 2.0 Stereo
          - 205125755c411c3b8622ca3175d27b37 # 3.0 Sound
          - 373b58bd188fc00c817bd8c7470ea285 # 4.0 Sound
          - 77ff61788dfe1097194fd8743d7b4524 # 5.1 Surround
          - 6fd7b090c3f7317502ab3b63cc7f51e3 # 6.1 Surround
          - e77382bcfeba57cb83744c9c5449b401 # 7.1 Surround
          - f2aacebe2c932337fe352fa6e42c1611 # 9.1 Surround


          # HDR Formats
          - 58d6a88f13e2db7f5059c41047876f00 # DV
          - e23edd2482476e595fb990b12e7c609c # DV HDR10
          - 55d53828b9d81cbe20b02efd00aa0efd # DV HLG
          - a3e19f8f627608af0211acd02bf89735 # DV SDR
          - e61e28db95d22bedcadf030b8f156d96 # HDR
          - 2a4d9069cc1fe3242ff9bdaebed239bb # HDR (undefined)
          - dfb86d5941bc9075d6af23b09c2aeecd # HDR10
          - b974a6cd08c1066250f1f177d7aa1225 # HDR10+
          - 9364dd386c9b4a1100dde8264690add7 # HLG
          - 08d6d8834ad9ec87b1dc7ec8148e7a1f # PQ

          # HQ Release Groups
          - ed27ebfef2f323e964fb1f61391bcb35 # HD Bluray Tier 01
          - c20c8647f2746a1f4c4262b0fbbeeeae # HD Bluray Tier 02
          - 5608c71bcebba0a5e666223bae8c9227 # HD Bluray Tier 03
          - 4d74ac4c4db0b64bff6ce0cffef99bf0 # UHD Bluray Tier 01
          - a58f517a70193f8e578056642178419d # UHD Bluray Tier 02
          - e71939fae578037e7aed3ee219bbe7c1 # UHD Bluray Tier 03
          - c20f169ef63c5f40c2def54abaf4438e # WEB Tier 01
          - 403816d65392c79236dcb6dd591aeda4 # WEB Tier 02
          - af94e0fe497124d1f9ce732069ec8c3b # WEB Tier 03

          # Misc
          - 9de657fd3d327ecf144ec73dfe3a3e9a # Dutch Groups
          - 0d91270a7255a1e388fa85e959f359d8 # FreeLeech
          - ff86c4326018682f817830ced463332b # MPEG2
          - 4b900e171accbfb172729b63323ea8ca # Multi
          - e7718d7a3ce595f289bfee26adc178f5 # Repack/Proper
          - ae43b294509409a6a13919dedd4764c4 # Repack2
          - 2899d84dc9372de3408e6d8cc18e9666 # x264
          - 9170d55c319f4fe40da8711ba9d8050d # x265

          # Movie Versions
          - eca37840c13c6ef2dd0262b141a5482f # 4K Remaster
          - e0c07d59beb37348e975a930d5e50319 # Criterion Collection
          - 0f12c086e289cf966fa5948eac571f44 # Hybrid
          - eecf3a857724171f968a66cb5719e152 # IMAX
          - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
          - 9d27d9d2181838f76dee150882bdc58c # Masters of Cinema
          - 09d9dd29a0fc958f9796e65c2a8864b4 # Open Matte
          - 570bc9ebecd92723d2d21500f4be314c # Remaster
          - 957d0f44b592285f26449575e8b1167e # Special Edition
          - e9001909a4c88013a359d0b9920d7bea # Theatrical Cut
          - db9b4c4b53d312a3ca5f1378f6440fc9 # Vinegar Syndrome

          # Optional
          - cae4ca30163749b891686f95532519bd # AV1
          - b6832f586342ef70d9c128d40c07b872 # Bad Dual Groups
          - f700d29429c023a5734505e77daeaea7 # DV (FEL)
          - 923b6abef9b17f937fab56cfcf89e1f1 # DV (WEBDL)
          - 90cedc1fea7ea5d11298bebd3d1d3223 # EVO (no WEBDL)
          - b17886cb4158d9fea189859409975758 # HDR10+ Boost
          - 73613461ac2cea99d52c4cd6e177ab82 # HFR
          - c465ccc73923871b3eb1802042331306 # Line/Mic Dubbed
          - ae9b7c9ebde1f3bd336a8cbd1ec4c5e5 # No-RlsGroup
          - 7357cf5161efbf8c4d5d0c30b4815ee2 # Obfuscated
          - 5c44f52a8714fdd79bb4d98e2673be1f # Retags
          - 9c38ebb7384dada637be8899efa68e6f # SDR
          - f537cf427b64c38c8e36298f657e4828 # Scene
          - ae4cfaa9283a4f2150ac3da08e388723 # VP9
          - 839bea857ed2c0a8e084f3cbdbd65ecb # x265 (no HDR/DV)

          # Streaming Services
          - b3b3a6ac74ecbd56bcdbefa4799fb9df # AMZN
          - 40e9380490e748672c2522eaaeb692f7 # ATVP
          - cc5e51a9e85a6296ceefe097a77f12f4 # BCORE
          - f6ff65b3f4b464a79dcc75950fe20382 # CRAV
          - 16622a6911d1ab5d5b8b713d5b0036d4 # CRiT
          - 84272245b2988854bfb76a16e60baea5 # DSNP
          - 509e5f41146e278f9eab1ddaceb34515 # HBO
          - 5763d1b0ce84aff3b21038eea8e9b8ad # HMAX
          - 526d445d4c16214309f0fd2b3be18a89 # Hulu
          - 2a6039655313bf5dab1e43523b62c374 # MA
          - 6a061313d22e51e0f25b7cd4dc065233 # MAX
          - 170b1d363bd8516fbf3a3eb05d4faff6 # NF
          - fbca986396c5e695ef7b2def3c755d01 # OViD
          - c9fd353f8f5f1baf56dc601c4cb29920 # PCOK
          - e36a0ba1bc902b26ee40818a1d59b8bd # PMTP
          - bf7e73dd1d85b12cc527dc619761c840 # Pathe
          - c2863d2a50c9acad1fb50e53ece60817 # STAN

          # Unwanted
          - b8cd450cbfa689c0259a01d9e29ba3d6 # 3D
          - ed38b889b31be83fda192888e2286d83 # BR-DISK
          - 90a6f9a284dff5103f6346090e6280c8 # LQ
          - bfd8eb01832d646a0a89c4deb46f8564 # Upscaled
          - dc98083864ea246d05a42df0d05f81cc # x265 (HD)

        # Uncomment the below properties to specify one or more quality profiles that should be
        # updated with scores from the guide for each custom format. Without this, custom formats
        # are synced to Radarr but no scores are set in any quality profiles.
        quality_profiles:
          - name: HD-1080p
          - name: Ultra-HD
        #    #score: -9999 # Optional score to assign to all CFs. Overrides scores in the guide.
        #    #reset_unmatched_scores: true # Optionally set other scores to 0 if they are not listed in 'names' above.

EOF

sleep 1
sudo docker exec recyclarr recyclarr sync radarr
sleep 5
sudo docker exec recyclarr recyclarr sync sonarr
sleep 5

#api key output
echo "Your Sonarr API Key is $sonarr_api_key"
echo "Your Radarr API Key is $radarr_api_key"
