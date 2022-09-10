#!/bin/bash

###############################################################################################################################
# This script will launch backup for etcd on master nodes based on the official method supported by Red Hat                   #
# https://docs.openshift.com/container-platform/4.10/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html #
#                                                                                                                             #
# The script is designed to work with OCP4.10                                                                                 #
#                                                                                                                             #
# The script will backup etcd by first checking the health of master nodes, if the number of healthy master nodes is 3 then   #
# the script will pick the first match to use for etcd backup. if two master nodes are healthy then the operator must confirm #
# that (s)he wishes to proceed.                                                                                               #
# 	                                                                                                                      #
# A debug pod will be used to run the backup script. and then a copy of the backup will be trasferred to the local machine    #
# under the /tmp directory                                                                                                    #
#                                                                                                                             #
# Property of Red Hat, all rights reserved.                                                                                   #
# Maintainer: azaky@redhat.com                                                                                                #
###############################################################################################################################


echo -e "\n \n"
echo "---------------------------------------------"
echo "Welcome! to the OCP backup script!"
echo "---------------------------------------------"
echo -e "\n \n"


# Add an alias to the session to make sure you are logged-in
# globals
export kubePass=$(cat ~/ocp-deployment/auth/kubeadmin-password)
export ocpServer=$(oc whoami --show-server)
	

# Make sure you're logged in to the OCP cluster
echo '** Trying to login to the cluster as admin! **' 
echo -e "\n \n"
eval oc login -u kubeadmin -p ${kubePass} ${ocpServer} > /dev/null
if [[ $? -eq 0 ]]
then
	echo '====> Login to OCP Cluster successful'
else
	echo '====> Could not login to the cluster, exiting now'
	exit 300
fi

# Check the health of the nodes
echo '** Checking the health of the master nodes **'
failedMasters= $(oc get nodes | grep master | grep -v Ready | awk '{print $1}')
declare -i numberFailedMasters=$(oc get nodes | grep master | grep -v Ready| wc -l)


# If the number of failed masters is greater than '1` then exit the script right away 
if [ $numberFailedMasters -gt 1 ]
then 
	echo    "--------------------------------------------------------------------------------------"
	echo    "Majority of Master nodes are down, backup can't start"
	echo -e "Failed Masters are: \n $failedMasters , Please contact support via access.redhat.com"
	echo    "--------------------------------------------------------------------------------------"
	
	echo " script is exiting now ..."
	exit 0
fi

# If all master nodes are healthy, then pick any of the master nodes to be used for backup
# the first hit is selected.

if [ $numberFailedMasters -eq 0 ]
then
	echo
	echo  '** All Master Nodes are healthy backup can start now **'
else
	echo "----------------------------------------------------------------------"  
	echo -e "Total Number Of Failed Masters: $numberFailedMasters, \n
			backup can continue but it is highly recommended to check the platform first"
	echo "----------------------------------------------------------------------"
	
	echo "----------------------------------------"
	echo -e "Failed Masters are: \n $failedMasters"
	echo "----------------------------------------"
	echo
fi

echo -e "** selected master for etcd backup $(oc get nodes | grep master | grep Ready | awk '{print $1}' | head -n1) **"
echo

echo -e "** check no debug Pod's running on $(oc get nodes | grep master | grep Ready | awk '{print $1}' | head -n1) **"
oldDebugPod=$(oc get pods | grep debug | awk {'print $1'})
if [[ -n $OldSessions ]]
	then
		eval oc delete pod $oldDebugPod
else 
	echo '====>  No debug pods were found'
fi
echo

echo '** Starting a new debug pod **'
echo
# Start a clean new debug pod and keep it running in the background
 
echo <<< $(oc debug node/$(oc get nodes | grep master | grep Ready | awk '{print $1}' | head -n1) &>/dev/null) &

# back-off to make sure the debug pod is running
echo '** Getting a 10 seconds nap to make sure the debug pod is started **'
sleep 10
echo


# Debug Pod Manipulation magic

debugPod=$(oc get pods | grep debug | awk {'print $1'})
echo -e "** debug pod $debugPod successfully started **"
echo 

echo '** cleaning all Previous backups on selected master node **'
oc exec  $debugPod -i -t -- rm -rf /host/home/core/assets/backup/
echo '====>  Previous old backups deleted from selected master node'
echo 

echo '** Making sure old backups are removed from the master node **'
oc exec $debugPod -i -t -- ls -lth  /host/home/core/assets/backup > /dev/null
if [[ $? -ne 0 ]]
then
	echo '====> No old debug pods on node'
else
	oc exec  $debugPod -i -t -- rm -rf /host/home/core/assets/backup/
	echo 'Old backup files deleted'
fi
echo

# start the backup process
echo  '** Running etcd backup **'
oc exec $debugPod -- chroot host /bin/bash /usr/local/bin/cluster-backup.sh /home/core/assets/backup &> /dev/null
if [[ $? -eq 0 ]]
then
	echo '====> etcd backup concluded successfully'
	echo
else
	echo '====> etcd backup failed, exiting now ...'
	exit 300
fi

echo '** Listing backup produced **'
oc exec $debugPod -i -t -- ls -lth  /host/home/core/assets/backup | awk {'print $9'}
echo

echo '** Moving the backup from the debugPod to local /tmp directory **'
oc exec $debugPod -- tar cf - /host/home/core/assets/backup | tar xf - -C /tmp/
while [[ $? -ne 0 ]]
do
	echo '====> tar & copy failed ... retrying ...'
	oc exec $debugPod -- tar cf - /host/home/core/assets/backup | tar xf - -C /tmp/
done
echo  '====>  Backup saved to /tmp directory'
echo

echo '** cleaning generated backup from master node to avoid exhausting space **'
oc exec  $debugPod -i -t -- rm -rf /host/home/core/assets/backup/
echo  '====>  All backups deleted from master node'
echo 

echo '** Removing the debug Pod  **'
eval oc delete pod $debugPod
echo '====>  Debug Pod Removed'
echo 

echo '** tar the local /tmp/host directory **'
rm -rf /tmp/host*.gz
tar -cjf /tmp/host_$(date +%F)_$(date +%T).tar.gz /tmp/host
tarball=$(ls -lth /tmp | grep host | awk {'print $9'})
echo -e " ====>  tarball $tarball saved under local /tmp directory"
echo 

echo '** Removing /tmp/host directory **'
rm -rf /tmp/host
echo '====>  /tmp/host directory successfully removed'
echo