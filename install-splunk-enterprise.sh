#!/bin/bash

# Splunk Enterprise version and build
SPLUNK_VERSION="9.4.3"
SPLUNK_BUILD="237ebbd22314"
SPLUNK_FILENAME="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-amd64.tgz"
DOWNLOAD_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_FILENAME}"

# PEM key file
KEY_FILE="idxside1.pem"

# Read each line from the CSV file (excluding the header)
tail -n +2 hosts.csv | while IFS=, read -r HOSTNAME USERNAME PASSWORD NEW_HOSTNAME; do

  if [[ -z "$HOSTNAME" || "$HOSTNAME" == hostname* ]]; then
    continue
  fi

  echo "🔁 Connecting to $HOSTNAME → Will change hostname to: $NEW_HOSTNAME"

  ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@"$HOSTNAME" <<EOF

    echo "🔧 Changing hostname to $NEW_HOSTNAME..."
    sudo hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "$NEW_HOSTNAME" | sudo tee /etc/hostname
    sudo sed -i '/127.0.1.1/d' /etc/hosts
    echo "127.0.0.1   localhost $NEW_HOSTNAME" | sudo tee -a /etc/hosts
    echo "✅ Hostname set to: \$(hostname)"

    echo "📥 Downloading Splunk Enterprise package to /tmp..."
    wget -O /tmp/$SPLUNK_FILENAME "$DOWNLOAD_URL"

    echo "⚙️ Installing Splunk in /opt as root..."
    sudo su - <<ROOT

      echo "📦 Extracting Splunk Enterprise to /opt..."
      tar -xvzf /tmp/$SPLUNK_FILENAME -C /opt/
      mv /opt/splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-amd64 /opt/splunk

      echo "🔐 Creating user-seed.conf with admin credentials..."
      mkdir -p /opt/splunk/etc/system/local
      cat <<SEED > /opt/splunk/etc/system/local/user-seed.conf
[user_info]
USERNAME = ${USERNAME}
PASSWORD = ${PASSWORD}
SEED

      echo "🚀 Enabling boot-start and starting Splunk..."
      /opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt
      /opt/splunk/bin/splunk start

      echo "✅ Splunk Enterprise installed and running on host: \$(hostname)"
ROOT

EOF

done
