#!/bin/bash

# Cloudflare settings
ZONE_ID=''
API_TOKEN=''
DOMAIN=''
SUBDOMAINS=('nextcloud') # List your subdomains here

# Log file location
LOG_FILE='/home/user/scripts/ddnslog.log'

# Function to log messages
log_message() {
    echo "$(date): $1" >> $LOG_FILE
}

# Fetch the current public IP
CURRENT_IP=$(curl -s http://ipv4.icanhazip.com)
if [ -z "$CURRENT_IP" ]; then
    log_message "ERROR: Failed to obtain current public IP."
    exit 1
fi

# Function to update DNS record
update_dns_record() {
    local record_name=$1
    local record_id=$2
    local ip=$3

    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
         -H "Authorization: Bearer $API_TOKEN" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\"}")

    if echo $UPDATE_RESPONSE | jq -e '.success'; then
        log_message "DNS record for $record_name updated successfully to $ip."
    else
        log_message "ERROR: Failed to update DNS record for $record_name."
        log_message "Response: $UPDATE_RESPONSE"
    fi
}

# Process each subdomain
for subdomain in "${SUBDOMAINS[@]}"; do
    FULL_DOMAIN="$subdomain.$DOMAIN"
    log_message "Processing $FULL_DOMAIN..."

    # Fetch the existing DNS record ID
    RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$FULL_DOMAIN" \
         -H "Authorization: Bearer $API_TOKEN" \
         -H "Content-Type: application/json")

    RECORD_ID=$(echo $RECORD_RESPONSE | jq -r '.result[0].id')
    EXISTING_IP=$(echo $RECORD_RESPONSE | jq -r '.result[0].content')

    if [ -z "$RECORD_ID" ] || [ -z "$EXISTING_IP" ]; then
        log_message "ERROR: Failed to fetch existing DNS record for $FULL_DOMAIN."
        continue
    fi

    # Compare and update if necessary
    if [ "$CURRENT_IP" != "$EXISTING_IP" ]; then
        update_dns_record $FULL_DOMAIN $RECORD_ID $CURRENT_IP
    else
        log_message "IP has not changed for $FULL_DOMAIN. No update required."
    fi
done

