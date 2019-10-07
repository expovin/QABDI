source config.sh deploy
source Helper.sh

helm install -n qadbi qadbi/bdi -f ./values.yaml 2>&1 | tee -a $LOG_FILE
if [ $? -eq 0 ]; then
    echo "   [OK]   Qlik Sense Engine package installed" 2>&1 | tee -a $LOG_FILE
else
    echo "   [ERROR]   while installing qliksense. Exit Program" 2>&1 | tee -a $LOG_FILE
    error_handling
fi


############################################################
# Copia dei dati e file di configurazione sul Cluster
#
# Copia del set di dati
podName=$(getPodId "qadbi-bdi-indexingmanager")
echo "Waiting $podName is started before coping data and config"
ready=0
while [[ $ready -eq 0 ]]
do
    echo -n "." 
    ready=$(kubectl get pods | grep qadbi-bdi-indexingmanager | awk '{print $2}' | awk -F'/' '{print $1}')     
done

echo "."
echo "Pod ready. Start coping data"
echo "Copy Input data"
podName=$(getPodId "qadbi-bdi-indexingmanager")
kubectl cp ./qabdi/data/* $podName:/home/data

echo "Copy mapping file"
# Copia dei file di configurazione
podName=$(getPodId "qadbi-bdi-indexingmanager")
kubectl cp ./qabdi/config/field_mappings_file.json $podName:/home/ubuntu/dist/runtime/config

echo "Copy index settings"
podName=$(getPodId "qadbi-bdi-indexingmanager")
kubectl cp ./qabdi/config/indexing_setting.json $podName:/home/ubuntu/dist/runtime/config

# Setting delle variabili di ambiente
echo "Setting env"
kubectl set env deployment/qadbi-bdi-indexingmanager BDICONFIGFOLDER=/home/ubuntu/qabdi/config BDIDATAFOLDER=/home/ubuntu/qabdi/data
kubectl set env deployment/qadbi-bdi-bastion BDICONFIGFOLDER=/home/ubuntu/qabdi/config BDIDATAFOLDER=/home/ubuntu/qabdi/data


# Creazione directory di output
echo "Creating output directory"
podName=$(getPodId "qadbi-bdi-indexingmanager")
kubectl exec -it $podName -- mkdir /home/output/nycsmall_output/


echo "*** 10) Getting the cluster IP" 2>&1 | tee -a $LOG_FILE
ready=0
cluster_ip="<none>"

while [[ $ready -eq 0 ]]
do
    echo -n "." 
    cluster_ip=$(kubectl get services | grep qadbi-nginx-ingress-controller | awk '{print $4}')    
    if valid_ip $cluster_ip; then 
        ready=1
    fi    
done
echo " " 2>&1 | tee -a $LOG_FILE
echo "   [OK]   Your cluster IP is "$cluster_ip" replace it in your hosts file" 2>&1 | tee -a $LOG_FILE


# Start servizi di indicizzazione
echo "Starting Indexing services"
podName=$(getPodId "qadbi-bdi-bastion")
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/indexer/start_indexing_env.sh
podName=$(getPodId "qadbi-bdi-indexingmanager")
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/listall.sh | grep /home/ubuntu/dist/indexer/indexer_tool | wc -l
podName=$(getPodId "qadbi-bdi-symbolserver")
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/listall.sh | grep /home/ubuntu/dist/indexer/indexer_tool | wc -l
podName=$(getPodId "qadbi-bdi-indexer")
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/listall.sh | grep /home/ubuntu/dist/indexer/indexer_tool | wc -l


podName=$(getPodId "qadbi-bdi-bastion")
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/indexer/task_manager.sh -r 1
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/indexer/task_manager.sh -r 3
kubectl exec -it $podName -- /home/ubuntu/dist/runtime/scripts/indexer/task_manager.sh -r a
