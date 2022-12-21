# Red Hat OCP backup shell script

The backup.sh script will launch backup for etcd on master nodes based on the official method supported by Red Hat:

https://docs.openshift.com/container-platform/4.10/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html

The script is designed & tested with OCP4.10, the script had been tested & verified to work with OCP running on top of AWS, GCP, IBM Clouds and Baremetal environments. In case of errors or suggestions please drop an email to the maintainer.

The script will backup etcd by first checking the health of master nodes, if the number of healthy master nodes is 3 then the script will pick the first healthy match to use for etcd backup. if two master nodes are healthy then the script will still proceed asking for confirmation while printing out a message to check the cluster and make sure to bring it to a nominal state.

If only one master is up then the script will fail to execute as the kube-api interface itself will be down and it is impossible to communicate with the cluster using oc commands, this is the time when a previous backup should be used and the recovery process should be executed:

either:
1. https://docs.openshift.com/container-platform/4.10/backup_and_restore/control_plane_backup_and_restore/replacing-unhealthy-etcd-member.html#replacing-unhealthy-etcd-member

or

2. https://docs.openshift.com/container-platform/4.10/backup_and_restore/control_plane_backup_and_restore/disaster_recovery/scenario-2-restoring-cluster-state.html#dr-scenario-2-restoring-cluster-state_dr-restoring-cluster-state

To realize the backup, a debug pod will be used to run the backup script. and then a copy of the backup will be trasferred to the local machine used to run this script under the /tmp directory.

The script logs in to the OCP cluster as kubeadmin, it assumes the kubeadmin-password file is saved under ~/ocp-deployment/auth/kubeadmin-password and it is hardwired in the code. You need to adapt the script to the right path else, the script will explicitly ask you to provide the cluster administrator username and password (be it kubeadmin or another user).

Property of Red Hat, all rights reserved.

https://github.com/AhmedAbdala/OCP-useful/blob/main/backup.sh

To directly download script: curl https://raw.githubusercontent.com/AhmedAbdala/OCP-useful/main/backup.sh

Maintainer: <azaky@redhat.com> 
            , <amzaky@linux.com>
