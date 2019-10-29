#!/bin/bash

startTimeScript=`date +%s`

AZ_RESOURCE_GROUP_NAME=$AZ_RESOURCE_GROUP_NAME-$startTimeScript
AZ_CLUSTER_NAME=$AZ_CLUSTER_NAME-$startTimeScript

###################################################################
# Setting the environments
source config.sh create

echo "Process started at "$startTimeScript                          2>&1 | tee $LOG_FILE                                 
echo "------------------------------------------------------------"  2>&1 | tee -a $LOG_FILE
echo "SUBSCRIPTION = "$AZ_SUBSCRIPTION                               2>&1 | tee -a $LOG_FILE
echo "TIME_OUT = "$TIME_OUT "sec."                                   2>&1 | tee -a $LOG_FILE
echo "RESOURCE_GROUP_NAME = "$AZ_RESOURCE_GROUP_NAME                 2>&1 | tee -a $LOG_FILE
echo "LOCATION = "$AZ_LOCATION                                       2>&1 | tee -a $LOG_FILE
echo "CLUSTER_NAME"=$AZ_CLUSTER_NAME                                 2>&1 | tee -a $LOG_FILE
echo "NUMBER_OF_NODES = "$AZ_NODE_COUNT                              2>&1 | tee -a $LOG_FILE
echo "DEFAULT_RESOURCE_GROUP = "$AZ_DEFAULT_RESOURCE_GROUP           2>&1 | tee -a $LOG_FILE
echo "VM_SIZE = "$AZ_VM_SIZE                                         2>&1 | tee -a $LOG_FILE
echo "ACCOUNT_NAME = "$AZ_ACCOUNT_NAME                               2>&1 | tee -a $LOG_FILE
echo "SKU_TYPES = "$AZ_SKU_TYPES                                     2>&1 | tee -a $LOG_FILE
echo "LOGIN_MODE="$LOGIN_MODE                                        2>&1 | tee -a $LOG_FILE
echo "------------------------------------------------------------"  2>&1 | tee -a $LOG_FILE

####################################################################

source Helper.sh

#Login into Azure account and select the correct subscriptions
echo "*** 1) Make sure you are logged in to Azure"
if [[ "$LOGIN_MODE" == "service-principal" ]] ; then
    az login --service-principal --username $appId --password $password --tenant $tenant 2>&1 | tee -a $LOG_FILE
    if [ $? -neq 0 ]; then
        echo "   [ERROR]   Login Error. Check your service-principal credential in the config.sh file. Exit program" 2>&1 | tee -a $LOG_FILE
        error_handling
    fi    
else
    az login 2>&1 | tee $LOG_FILE
fi

echo "   [OK]   Logged in Azure account" 2>&1 | tee -a $LOG_FILE



echo "*** 2) Enable AKS for your Azure account" 2>&1 | tee -a $LOG_FILE
az account set --subscription "$AZ_SUBSCRIPTION" 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   " $AZ_SUBSCRIPTION "subscription selected" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while selecting subscription" $AZ_SUBSCRIPTION ". Exit program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


az provider register -n Microsoft.ContainerService 2>&1 | tee -a $LOG_FILE
az provider register -n Microsoft.Compute 2>&1 | tee -a $LOG_FILE
echo "   [OK]   Provider registred, checking when ready" 2>&1 | tee -a $LOG_FILE

ready=0
isContainerServiceReady=0
isComputeReady=0
counter=1

while [ $ready -eq 0 ]
do
   echo -n "."
   counter=$(( $counter + 1 ))

   #Timeout escaping the script with error
   if [[ $counter -gt $TIME_OUT ]] ; then              
       echo "Timeout while waiting provider registation status ready" 2>&1 | tee -a $LOG_FILE
       error_handling
   fi

   #Checking Microsoft.ContainerService and Microsoft.Compute registration status
   ContainerService=$(az provider show -n Microsoft.ContainerService | grep registrationState | awk '{print $2}' | awk -F'"' '{print $2}')
   Compute=$(az provider show -n Microsoft.Compute | grep registrationState | awk '{print $2}' | awk -F'"' '{print $2}')
   if [[ "$ContainerService" == "Registered" && $isContainerServiceReady -eq 0 ]] ;  then
       isContainerServiceReady=1
       echo " " 2>&1 | tee -a $LOG_FILE
       echo "   [OK]   Microsoft.ContainerService registration suceed!"  2>&1 | tee -a $LOG_FILE
   fi

   if [[ "$Compute" == "Registered"  && $isComputeReady -eq 0 ]] ;  then
       isComputeReady=1
       echo " " 2>&1 | tee -a $LOG_FILE
       echo "   [OK]   Microsoft.Compute registration suceed!" 2>&1 | tee -a $LOG_FILE
   fi   

   if [[ $isComputeReady -eq 1 && $isContainerServiceReady -eq 1 ]] ; then
       echo "   [OK]   Both component registration suceed. go to next step" 2>&1 | tee -a $LOG_FILE
       ready=1
   fi
done


echo "*** 3) Create a Resource Group" 2>&1 | tee -a $LOG_FILE
az group create --name $AZ_RESOURCE_GROUP_NAME --location $AZ_LOCATION 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Resource group "$AZ_RESOURCE_GROUP_NAME" has been created in "$AZ_LOCATION 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while selecting resource group" $AZ_RESOURCE_GROUP_NAME "in region $AZ_LOCATION. Exit program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


echo "*** 4) Create the Cluster" 2>&1 | tee -a $LOG_FILE
echo "***    This command will take around 15-20 minutes to run. You can also monitor progress in the Azure Portal." 2>&1 | tee -a $LOG_FILE
az aks create \
    --resource-group $AZ_RESOURCE_GROUP_NAME \
    --name $AZ_CLUSTER_NAME \
    --node-count $AZ_NODE_COUNT \
    --generate-ssh-keys \
    --node-vm-size $AZ_VM_SIZE 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Cluster creation complete" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while selecting Cluster Exit program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi



echo "*** 5) Get Credentials and Configure kubectl" 2>&1 | tee -a $LOG_FILE
az aks get-credentials --resource-group=$AZ_RESOURCE_GROUP_NAME --name=$AZ_CLUSTER_NAME --overwrite-existing 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Credential acquired" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while getting credential. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi



echo "*** 6) Role Based Access Control (RBAC)" 2>&1 | tee -a $LOG_FILE
kubectl create -f ./rbac-config.yaml 2>&1 | tee -a $LOG_FILE
echo "   [OK]   Service account for Tiller created and binded it to the ClusterRole" 2>&1 | tee -a $LOG_FILE
helm init --upgrade --service-account tiller --wait 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then 
    echo "   [OK]   HELM initialized" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while initializing HELM. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi

echo "Looking for resource group "$AZ_DEFAULT_RESOURCE_GROUP 2>&1 | tee -a $LOG_FILE
foundResourceGroup=$(az group list -o table | grep $AZ_DEFAULT_RESOURCE_GROUP | wc -l)
if [[  $foundResourceGroup -eq 1 ]] ;  then
    echo "   [OK]   Resource group found" 2>&1 | tee -a $LOG_FILE
else 
    echo "   [OK]   [WARNING] Default Resource group not found. Please insert the name" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


echo "*** 7) Create a Storage Account" 2>&1 | tee -a $LOG_FILE
az storage account create -g $AZ_DEFAULT_RESOURCE_GROUP -n $AZ_ACCOUNT_NAME --sku $AZ_SKU_TYPES 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Storage Account created" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while creating Storage account. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


echo "*** 8) Azure Storage" 2>&1 | tee -a $LOG_FILE
kubectl create clusterrole system:azure-cloud-provider --verb=get,create --resource=secrets 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Cluster role that can create secrets created" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while creating custom role. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


kubectl create clusterrolebinding \
    system:azure-cloud-provider \
    --clusterrole=system:azure-cloud-provider \
    --serviceaccount=kube-system:persistent-volume-binder 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Cluster role binded" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while creating cluster binding. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi



kubectl apply -f azure-sc.yaml 2>&1 | tee -a $LOG_FILE
echo "   [OK]   Class Storage Created" 2>&1 | tee -a $LOG_FILE

echo "*** 9) Install QSEoK" 2>&1 | tee -a $LOG_FILE
helm repo add qadbi https://qlik.bintray.com/qabdicharts  2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Add Qlik stable repo to helm" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while adding Qlik Stable repo to HELM. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


## Deploy ########
./AZ_Deploy.sh

#################################################################
# Console di amministrazione

kubectl create -f user.yaml
kubectl create -f ClusterRoleBinding.yaml


az logout
echo "   [OK]   Logged out from Azure" 2>&1 | tee -a $LOG_FILE

endTimeScript=`date +%s`
runtimeScript=$((endTimeScript-startTimeScript))

echo "Process ended at "$endTimeScript                          2>&1 | tee -a $LOG_FILE  

if [[ "$LOGIN_MODE" == "service-principal" ]] ; then
    #If the process is unattended send the email with the IP Address and the config file
    echo "<h1>QSEoK Cluster Creation</h1>" > $EMAIL_MESSAGE_BODY_FILE
    echo "QSEoK deployment and installation is complete in $runtimeScript sec. You need to add this line in your file /etc/hosts" >> $EMAIL_MESSAGE_BODY_FILE
    echo "<b>$cluster_ip    $HOST_NAME</b>" >> $EMAIL_MESSAGE_BODY_FILE
    echo " " >> $EMAIL_MESSAGE_BODY_FILE
    echo "Point your browser to <a href='https://$HOST_NAME/console'>https://$HOST_NAME/console</a> you need to login using the Auth0 application user" >> $EMAIL_MESSAGE_BODY_FILE
    echo "Once signed in, apply the license as reported below" >> $EMAIL_MESSAGE_BODY_FILE
    echo "<b>$QS_LICENSE</b>" >> $EMAIL_MESSAGE_BODY_FILE
    echo " "
    echo "You can find in attach the kubectl config file."


    sendEmail -f \""$EMAIL_SENDER\""\
        -t "$EMAIL_RECIPIENTS"\
        -u \""$EMAIL_SUBJECT_CREATE\""\
        -o message-file="$EMAIL_MESSAGE_BODY_FILE"\
        -s "$EMAIL_SMTP_SERVER"\
        -xu $EMAIL_USERNAME -xp $EMAIL_PASSWORD -a "$LOG_FILE" "$HOME/.kube/config"\
        -v -o tls=yes -o message-content-type=html 2>&1 | tee -a $LOG_FILE
else
    # If the process is Supervised try to add the new hots in the /etc/host file 
    echo "  Removing the hostname from /etc/hosts file" 2>&1 | tee -a $LOG_FILE
    ./manage-etc-hosts.sh removeline $HOST_NAME 2>&1 | tee -a $LOG_FILE
    echo "   Add the new entry to /etc/hosts file" 2>&1 | tee -a $LOG_FILE
    ./manage-etc-hosts.sh addline $HOST_NAME $cluster_ip 2>&1 | tee -a $LOG_FILE
fi


echo ""
echo "type --> watch kubectl get pods <-- to check the pods' status"
echo



echo "..."
echo "Script ended in $runtimeScript sec. Installation complete"


#kubectl cp data/* qadbi-bdi-indexingmanager-5bcdfc7c5d-fpqc5:/home/data
#kubectl cp config/indexing_setting.json qadbi-bdi-indexingmanager-5bcdfc7c5d-fpqc5:/home/ubuntu/dist/runtime/config
#kubectl cp config/cluster.json qadbi-bdi-indexingmanager-5bcdfc7c5d-fpqc5:/home/ubuntu/dist/runtime/config
#kubectl cp config/field_mappings_file.json qadbi-bdi-indexingmanager-5bcdfc7c5d-fpqc5:/home/ubuntu/dist/runtime/config
#kubectl set env deployment/qadbi-bdi-indexingmanager BDICONFIGFOLDER=/home/ubuntu/qabdi/config BDIDATAFOLDER=/home/ubuntu/qabdi/data
#kubectl exec -it qadbi-bdi-indexingmanager-5bcdfc7c5d-fpqc5 -- mkdir /home/output/nycsmall_output/
