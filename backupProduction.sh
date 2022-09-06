#!/bin/bash

###############################################################################################################################
# This script will launch backup for etcd on master nodes based on the official method supported by Red Hat                   #
# https://docs.openshift.com/container-platform/4.10/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html #
#                                                                                                                             #
# The script is designed to work with OCP4.10 and not tested for backward compatibility.                                      #
#                                                                                                                             #
# The following packages are needed to successfully run the script:-                                                          #
#     - tmux                                                                                                                  #
#     - expect                                                                                                                #
#                                                                                                                             #
#                                                                                                                             #
# Property of Red Hat, all rights reserved.                                                                                   #
# Maintainer: azaky@redhat.com                                                                                                #
###############################################################################################################################


echo -e "\n \n"
echo "---------------------------------------------"
echo "Welcome! to the OCP backup script!"
echo "---------------------------------------------"
echo -e "\n \n"


echo "checking the presence of prerequisite packages ... "
package_tmux=$(rpm -qa | grep tmux)
if [[ -n ${package_tmux} ]]; then
	echo "tmux package is installed, backup can proceed \n \n"
elif [[ -z ${package_tmux} ]]; then
	echo "Attempting to install missing tmux package \n \n"
	dnf install tmux -y 
fi

#Add an alias to the session to make sure you are logged in
export kubePass=$(cat /home/stc/ocp-deployment/auth/kubeadmin-password)
export ocpServer=$(oc whoami --show-server)


# Make sure you're logged in to the OCP cluster
echo '***** Trying to login to the cluster as admin! *****' 
echo -e "\n \n"
eval oc login -u kubeadmin -p ${kubePass} ${ocpServer}

# Check the health of the nodes
echo '***** Checking the health of the master nodes *****'
failedMasters= $(oc get nodes | grep master | grep -v Ready | awk '{print $1}')
declare -i numberFailedMasters=$(oc get nodes | grep master | grep -v Ready| wc -l)


# If the number of failed masters is greater than '1` then exit the script right away 
if [ $numberFailedMasters -gt 1 ]
then 
	echo  "--------------------------------------------------------------------------------------"
	echo  "Majority of Master nodes are down, backup can't start"
	echo -e "Failed Masters are: \n $failedMasters , Please contact support via access.redhat.com"
	echo  "--------------------------------------------------------------------------------------"
	
	echo " script is exiting now ..."
	exit 0
fi

# If all master nodes are healthy, then pick any of the master nodes to be used for backup
# the first hit is selected.

if [ $numberFailedMasters -eq 0 ]
then
	echo
	echo  '***** All Master Nodes are healthy backup can start now *****'
else
	echo "----------------------------------------------------------------------"  
	echo -e "Total Number Of Failed Masters: $numberFailedMasters, \n
			backup can continue but it is highly recommended to check the platform first"
	echo "----------------------------------------------------------------------"
	
	echo "----------------------------------------"
	echo -e "Failed Masters are: \n $failedMasters"
	echo "----------------------------------------"
fi


# start a debug pod towards one of the healthy masters, First healthy hit is selected
echo -e "***** Executing: oc debug node/$(oc get nodes | grep master | grep Ready | awk '{print $1}' | head -n1) *****"


eval oc debug node/$(oc get nodes | grep master | grep Ready | awk '{print $1}' | head -n1) -- chroot /host /bin/bash  /usr/local/bin/cluster-backup.sh /home/core/assets/backup

# Start a new tmux session towards the debug pod, if the same bash session is æused the script will halt.
echo '***** Starting a new remote tmux session to keep debug pod up & running *****'

# Check if there are any old running tmux sessions under the same name, if the old session was not released correctly then kill the old session(s)
echo '***** Checking & Killing any previous hanging tmux resources! ***** '
OldSessions=$(tmux ls | grep backupSession | awk {'print $1'} | tr ':' '\n')

declare -i numOldSessions=$(tmux ls | grep backupSession | awk {'print $1'} | wc -l)
for i in $(tmux ls | grep backupSession | awk {'print $1'} | wc -l); do eval tmux kill-session -t $OldSessions; done



# Start a clean tmux session for backup, the name of the session is "backupSession"
tmux new -d -s backupSession
tmux send-keys -t backupSession.0 "oc debug node/$(oc get nodes | grep master | grep Ready | awk '{print $1}' | head -n1)" ENTER

# back-off to make sure the debug pod is running
sleep 5

# Debug Pod Manipulation magic
debugPod=$(oc get pods | grep debug | awk {'print $1'})

echo '***** Listing backups saved on master node under /host/home/core/assets/backup *****'
oc exec $debugPod -i -t -- ls -lth  /host/home/core/assets/backup 
echo

echo '***** Saving backup contents to local /tmp directory *****'
oc exec $debugPod -- tar cf - /host/home/core/assets/backup | tar xf - -C /tmp/
echo 'Backup saved to /tmp directory'
echo

echo '***** cleaning all backups from master node *****'
oc exec  $debugPod -i -t -- rm -rf /host/home/core/assets/backup/
echo 'All backups deleted from master node'
echo 

echo '***** Removing the debug Pod  *****'
eval oc delete pod $debugPod
echo "Debug Pod $debugPod Removed"
echo 

echo '***** tar the local /tmp/host directory *****'
tar -cjf /tmp/host.tar.gz /tmp/host
echo '***** tarball is saved under /tmp/host.tar.gz directory *****'


echo '***** Killing tmux session backupSession *****'
tmux kill-session -t backupSession

