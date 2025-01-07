#!/bin/bash

## BLUF: This script will create a custom Docker network for the vault and tunnel containers. You can use the preset values, or choose your favorite IP scheme.

## MACVLAN SETUP (OPTIONAL):      (Example Script at the end)
## If you would like to use an existing IP address on your home network for management purposes, you can go with a macvlan network setup:
## To do so, change the 'DRIVER' variable below from "bridge" to "macvlan".
## Next, ensure the 'CIDR' and 'GATEWAY' variables match those of your home network settings (check the LAN settings of your router, if you aren't sure).
## Finally, un-comment the 'IP_RANGE' lines below and enter in a suitable IP range on line (this step requires a bit of CIDR knowledge).
## (choose an IP range that isn't too restrictive and won't cause IP conflicts with other network devices. I recommend using a chunk from the latter half of your IP pool; i.e., x.x.x.192/26)

## If deviating from any of the pre-defined values, you'll need to modify the .env file next:
## Change the 'BW_IP' (../.env==line 5) and 'CF_IP' (../.env==line 13) variables to match your newly defined IP range.

# Variables:
SUBNET="172.31.20."

NETWORK_NAME="$VAULT_NET"
CIDR="${SUBNET}0/28"
GATEWAY="${SUBNET}1"
DRIVER="bridge"
#IP_RANGE="${SUBNET}0/27"

docker network create \
--driver="$DRIVER" \
--attachable \
--subnet="$CIDR" \
--gateway="$GATEWAY" \
"$NETWORK_NAME"

################################

## MACVLAN Example Script:

#docker network create \
#--driver=macvlan \
#--attachable \
#--subnet=192.168.0.0/24 \
#--gateway=192.168.0.1 \
#--ip-range=192.168.0.224/27 \
#trafalgar-net
