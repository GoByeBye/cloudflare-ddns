#!/usr/bin/env bash

# This script is used to update IP of the domains in Cloudflare's DNS records.
# It is intended to be run as a cron job.
# This script is based on the work of @K0p1-Git/cloudflare-ddns-updater (On GitHub)

verifyPrerequisites() {
  if ! command -v curl &> /dev/null
    then
        echo "curl could not be found"
        exit
    fi
}

configureDNS() {
  # Export variables from the .env file and make them available to the curl command
  export $(grep -v '^#' .env | xargs)
  # Fetch our public IP address
  local intReturnCode
  strPublicIP=$(curl -s https://api.ipify.org); intReturnCode=$?

  # Error handling just in case ipify fails to return one
  if [[ $int$intReturnCode != 0 ]]; then
    # attempt to fetch our public IP from alternative website(s)
    strPublicIP=$(curl -s https://ifconfig.me/ip || curl -s https://icanhazip.com); intReturnCode=$?
    if [[ $int$intReturnCode != 0 ]]; then
      echo "Failed to fetch public IP address. Please check your internet connection."
      exit 1
    fi
  fi

  # Verify that the IP is a valid IPV4 address
  if [[ ! $strPublicIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "IPv4 regex did not find a valid ip in the ip $strPublicIP. If this is a false error please report it."
    exit 2 # Missing or invalid public IP address
  fi

  if [[ $AUTH_METHOD == "global" ]]; then
    AUTH_HEADER="X-Auth-Key:"
  else
    AUTH_HEADER="Authorization: Bearer"
  fi

  echo "Checking for A record of $strDomainName"
  strRecord=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$strZoneID/dns_records?type=A&name=$strDomainName" \
                      -H "X-Auth-Email: $AUTH_EMAIL" \
                      -H "$AUTH_HEADER $AUTH_KEY" \
                      -H "Content-Type: application/json")

  # Check if the record exists
  if [[ $strRecord == *"\"count\":0"* ]]; then
    echo "No record was found for $strDomainName. Please create one manually."
    exit 2
  fi

  # Get the record IP addres based on
  # https://github.com/K0p1-Git/cloudflare-ddns-updater/blob/88c73e30f86227e45a9410540b1d45697088f4b4/cloudflare-template.sh#L66
  strRecordIP=$(echo "$strRecord" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
  if [[ $strRecordIP == "$strPublicIP" ]]; then
    echo "No need to update. IP address is the same."
     if [[ $intDomainsToCheck != 1 ]]; then
      echo "Skipping to next domain."
      return
    else
      exit 0
    fi
  fi

  # Get the record ID
  strRecordID=$(echo "$strRecord" | sed -E 's/.*"id":"(\w+)".*/\1/')

  # This is a string because it returns json data btw
  strUpdate=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$strZoneID/dns_records/$strRecordID" \
                     -H "X-Auth-Email: $AUTH_EMAIL" \
                     -H "$AUTH_HEADER $AUTH_KEY" \
                     -H "Content-Type: application/json" \
                     --data "{\"type\":\"A\",\"name\":\"$strDomainName\",\"content\":\"$strPublicIP\",\"ttl\":\"$TTL\",\"proxied\":${PROXY}}"); intReturnCode=$?

  # If this is not 0 someone fucked up something
  if [[ $intReturnCode != 0 ]]; then
    echo "Failed to update the record. Please check your internet connection. Exit code $intReturnCode"
    exit 1
  fi

  # Report the status of the update
  if [[ $strUpdate == *"\"success\":false"* ]]; then
    echo "Failed to update $strDomainName."
    echo "Dump: $strUpdate"
    if [[ $intDomainsToCheck != 1 ]]; then
      echo "Skipping to next domain."
      return
    else
      exit 1
    fi
  else
    echo "Successfully updated $strDomainName."
  fi


    # Report the status of the update to Discord
  if [[ $DISCORD_WEBHOOK_URL != "" ]]; then
    if [[ $strUpdate == *"\"success\":false"* ]]; then
      strStatus="Failed to update $strDomainName."
      strError=$(echo $strUpdate | grep -Po '(?<="message":")[^"]*')
      # See comment on line 110 for why this is horrible
      strMessage="{\"username\": \"${DISCORD_WEBHOOK_USERNAME}\", \"avatar_url\": \"${DISCORD_WEBHOOK_AVATAR_URL}\", \"content\": \"${strStatus} Error: ${strError}\"}"
    else
      strStatus="Successfully updated $strDomainName. New IP: $strPublicIP"
      # This is unreadable garbage, bnut to explain it, first bit sets the username second is the message content
      strMessage="{\"username\": \"${DISCORD_WEBHOOK_USERNAME}\", \"avatar_url\": \"${DISCORD_WEBHOOK_AVATAR_URL}\", \"content\": \"${strStatus}\"}"
    fi
    curl -s -X POST -H "Content-Type: application/json" -d "$strMessage" "$DISCORD_WEBHOOK_URL"
  fi
}


main() {
  verifyPrerequisites

  while IFS= read -r line; do
    local domain
    local zoneID
    domain=$(echo "$line" | cut -d' ' -f1)
    zoneID=$(echo "$line" | cut -d' ' -f2)


    local domains
    local zoneIDs

    # Add the domain and zoneID to the array
    domains+=("$domain")
    zoneIDs+=("$zoneID")
  done < records.txt


  intDomainsToCheck=${#domains[@]}


  # Discord webhook configuration
  if [[ $DISCORD_WEBHOOK_USERNAME == "" ]]; then
    DISCORD_WEBHOOK_USERNAME="Cloudflare DDNS Updater"
  fi

  if [[ $DISCORD_WEBHOOK_AVATAR_URL == "" ]]; then
    # Straight up something I found from googling "cloudflare logo"
    DISCORD_WEBHOOK_AVATAR_URL="https://i.imgur.com/7FAeSaN.png"
  fi

  # Loop through all the domains and update them
  for ((i=0; i<${#domains[@]}; i++)); do
    strDomainName=${domains[$i]}
    strZoneID=${zoneIDs[$i]}
    configureDNS
    intDomainsToCheck=$((intDomainsToCheck-1))
  done
  echo "Done updating domains"
}

main