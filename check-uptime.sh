#!/bin/sh

#  check-uptime.sh
#  OCP
#
#  Created by Ahmed ZAKY on 22/09/2022.
#  

oc get nodes
echo
echo
failedNodes=$(oc get nodes | cut -d ' ' -f4 |grep [^Ready] |wc -l)
failedNodesNames=$(oc get nodes |grep NotReady |awk '{print $1}')
if  test $failedNodes -eq 0
then
        echo  "---------------------"
        echo  "All Nodes are healthy"
        echo  "---------------------"
else
        echo "-------------------------------------------"
        echo -e "Total Number Of Failed Nodes: $failedNodes"
        echo "-------------------------------------------"
        echo
        echo "-----------------------------"
        echo "Identified Failed Nodes Are"
        echo "-----------------------------"
        echo
        echo -e "$failedNodesNames"
        echo "-----------------------------"


fi

echo
echo
echo -e "-----------------------"
echo -e "Available Master Nodes:"
echo -e "-----------------------"
oc get nodes |grep master |awk '{print $1}' |tr '\n' ','
echo -e "\n"

for i in $(oc get nodes |grep master |awk '{print $1}'); do echo -e "uptime for $i is: " ;ssh core@$i uptime; echo -e "\n"; done
echo -e "\n"

echo -e "-----------------------"
echo -e "Available Worker Nodes:"
echo -e "-----------------------"
oc get nodes |grep -i app |awk '{print $1}' |tr '\n' ','
echo -e "\n"

for i in $(oc get nodes |grep -i app |awk '{print $1}'); do echo -e "uptime for $i is: " ;ssh core@$i uptime;echo -e "\n" ;done
echo -e "\n"



echo -e "-----------------------"
echo -e "Available Infra Nodes: "
echo -e "-----------------------"
oc get nodes |grep -i infra |awk '{print $1}' |tr '\n' ','
echo -e "\n"

for i in $(oc get nodes |grep -i infra |awk '{print $1}'); do echo -e "uptime for $i is: " ;ssh core@$i uptime;echo -e "\n" ;done
echo -e "\n"
