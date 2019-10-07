source Helper.sh
podName=$(getPodId "qadbi-bdi-indexingmanager")
echo $podName


#loadBalancingRow="<none>"
#echo "Getting the Cluster IP:"
#ready=0
#while [[ $ready -eq 0 ]]
#do
#    echo -n "."
    cluster_ip=$(cat test.txt | grep LoadBalancer | awk '{print $4}')  
#    if valid_ip $cluster_ip; then 
#        ready=1
#    fi
#    sleep 1
#done

#echo "Found IP "$cluster_ip