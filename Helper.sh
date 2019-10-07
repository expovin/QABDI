#!/bin/bash
 
 function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function error_handling()
{

    sendEmail -f \""$EMAIL_SENDER\""\
        -t "$EMAIL_RECIPIENTS"\
        -u \""$EMAIL_SUBJECT_ERRORCRE\""\
        -o message-file="$EMAIL_MESSAGE_BODY_FILE"\
        -s "$EMAIL_SMTP_SERVER"\
        -xu "$EMAIL_USERNAME" -xp "$EMAIL_PASSWORD" -a "$LOG_FILE"\
        -v -o tls=yes -o message-content-type=html 2>&1 | tee -a $LOG_FILE


    exit 100
}

function getPodId()
{
    local podName=$(kubectl get pod | grep $1 | awk '{print $1}')
    echo $podName
}


