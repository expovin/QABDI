
source config.sh destroy
echo $AZ_DEFAULT_RESOURCE_GROUP
startTimeScript=`date +%s`

echo "Process started at "$startTimeScript                          2>&1 | tee $LOG_FILE 

if [[ "$LOGIN_MODE" == "service-principal" ]] ; then
    az login --service-principal --username $appId --password $password --tenant $tenant 2>&1 | tee -a $LOG_FILE
    if [ $? -neq 0 ]; then
        echo "   [ERROR]   Login Error. Check your service-principal credential in the config.sh file. Exit program" 2>&1 | tee -a $LOG_FILE
        error_handling
    fi    
else
    az login
fi
echo "    [OK]    You are logged in" 2>&1 | tee $LOG_FILE
echo "===> Removing all Deployments" 2>&1 | tee $LOG_FILE
helm del --purge qadbi 2>&1 | tee $LOG_FILE

echo "===> Remove all resources" 2>&1 | tee $LOG_FILE
az group delete -g $AZ_DEFAULT_RESOURCE_GROUP --verbose -y 2>&1 | tee $LOG_FILE

# Switch current context
kubectl config use-context minikube
# Delete old context
kubectl config delete-context $AZ_CLUSTER_NAME


#az aks delete --name qseok-clust-ves --resource-group MC_qseok_ves_qseok-clust-ves_westeurope --yes

if [[ "$LOGIN_MODE" == "service-principal" ]] ; then
    echo "<h1>QSEoK Cluster Distruction</h1>" > $EMAIL_MESSAGE_BODY_FILE 2>&1 | tee $LOG_FILE
    echo "QSEoK Cluster has been destroyed" >> $EMAIL_MESSAGE_BODY_FILE 2>&1 | tee $LOG_FILE

    sendEmail -f \""$EMAIL_SENDER\""\
        -t "$EMAIL_RECIPIENTS"\
        -u \""$EMAIL_SUBJECT_DESTROY\""\
        -o message-file="$EMAIL_MESSAGE_BODY_FILE"\
        -s "$EMAIL_SMTP_SERVER"\
        -xu $EMAIL_USERNAME -xp $EMAIL_PASSWORD -a "$LOG_FILE"\
        -v -o tls=yes -o message-content-type=html 2>&1 | tee -a $LOG_FILE
else
    ./manage-etc-hosts.sh removeline $HOST_NAME
    echo "   [OK]   Removed host "$HOST_NAME" from /etc/hosts file"
fi


az logout
echo "   [OK]   Logged out from Azure"
