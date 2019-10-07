#!/bin/bash 

# Add HOST      ./manage-etc-hosts.sh addline my.test.com 1.1.1.1
# Delete Host   ./manage-etc-hosts.sh removeline my.test.com

# PATH TO YOUR HOSTS FILE
ETC_HOSTS=/etc/hosts

# DEFAULT IP FOR HOSTNAME
IP=$3
HOST=$2
# Hostname to add/remove.
HOSTLINE="$3 $2"

echo "+$1+$HOSTLINE+"

removeline() {
  if [ -n "$(grep -E "$HOST$" $ETC_HOSTS)" ]; then
    echo "$HOST Found in your $ETC_HOSTS, Removing now...";
    lineNumber=$(cat $ETC_HOSTS | grep -n $HOST | awk -F":" '{print $1}')
    lineNumber=$lineNumber"d"
    #echo "sudo sed -i '$lineNumber' $ETC_HOSTS"
    sudo sed -i $lineNumber $ETC_HOSTS
  else
    echo "$HOST was not found in your $ETC_HOSTS"
  fi
}

addline() {
  if [ -n "$(grep -E "^$HOSTLINE$" $ETC_HOSTS)" ]; then
    echo "$HOSTLINE Found in your $ETC_HOSTS, Removing now...";
  else
    echo "$HOSTLINE was not found in your $ETC_HOSTS, Adding now...";
    sudo -- sh -c -e "echo '$HOSTLINE' >> /etc/hosts";

    if [ -n "$(grep -E "^$HOSTLINE$" $ETC_HOSTS)" ]; then
      echo "$HOSTLINE was added successfully";
    else
      echo "Failed to Add $HOSTLINE, Try again!"
    fi

  fi
}

$1