#!/bin/bash

set -e

echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "🐳 Installing Docker and Docker Compose..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |         sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose

echo "🧱 Creating directories for data persistence..."
mkdir -p ~/sdrhub/{grafana,data,influxdb,mosquitto,telegraf,rtl_433,config}

echo "📄 Writing docker-compose.yml..."
cat <<EOF > ~/sdrhub/docker-compose.yml
version: '3.8'

services:
  influxdb:
    image: influxdb:1.8
    container_name: influxdb
    volumes:
      - ./influxdb:/var/lib/influxdb
    ports:
      - "8086:8086"
    environment:
      - INFLUXDB_DB=sensors
      - INFLUXDB_ADMIN_USER=admin
      - INFLUXDB_ADMIN_PASSWORD=Fredmay25!!
    restart: unless-stopped

  grafana:
    image: grafana/grafana-oss
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=Fredmay25!!
    volumes:
      - ./grafana:/var/lib/grafana
    restart: unless-stopped

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto:/mosquitto/config
    restart: unless-stopped

  telegraf:
    image: telegraf
    container_name: telegraf
    volumes:
      - ./telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro
    depends_on:
      - influxdb
    restart: unless-stopped

  rtl_433:
    image: hertzg/rtl_433
    container_name: rtl_433
    devices:
      - "/dev/bus/usb:/dev/bus/usb"
    command: >
      -F json -M utc -C si
      -F mqtt://mosquitto
    restart: unless-stopped
EOF

echo "✅ Done. Run the following to start the stack:"
echo "cd ~/sdrhub && sudo docker-compose up -d"


echo "🛠 Writing telegraf.conf..."
cat <<EOF > ~/sdrhub/telegraf/telegraf.conf
[[outputs.influxdb]]
  urls = ["http://influxdb:8086"]
  database = "sensors"
  username = "admin"
  password = "Fredmay25!!"

[[inputs.mqtt_consumer]]
  servers = ["tcp://mosquitto:1883"]
  topics = ["rtl_433/#"]
  data_format = "json"
EOF

echo "🛠 Writing mosquitto.conf..."
mkdir -p ~/sdrhub/mosquitto/config
cat <<EOF > ~/sdrhub/mosquitto/config/mosquitto.conf
allow_anonymous true
listener 1883
listener 9001
protocol websockets
EOF

echo "🎉 Installation script and all config files are ready!"
