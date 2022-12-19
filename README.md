# Red Hat

The backup.sh script will launch backup for etcd on master nodes based on the official method supported by Red Hat:
https://docs.openshift.com/container-platform/4.10/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html

The script is designed to work with OCP4.10

The script will backup etcd by first checking the health of master nodes, if the number of healthy master nodes is 3 then
the script will pick the first match to use for etcd backup. if two master nodes are healthy then the operator must confirm
that (s)he wishes to proceed.

A debug pod will be used to run the backup script. and then a copy of the backup will be trasferred to the local machine
under the /tmp directory

The script logs in to the OCP cluster as kubeadmin, it assumes the kubeadmin-password file is saved under
~/ocp-deployment/auth/kubeadmin-password and it is hardwired in the code. You need to adapt the script to the right path
to make sure of the correct execution.

Property of Red Hat, all rights reserved.
https://github.com/AhmedAbdala/OCP-useful/blob/main/backup.sh
To directly download script: curl https://raw.githubusercontent.com/AhmedAbdala/OCP-useful/main/backup.sh

Maintainer: <azaky@redhat.com> 
            <amzaky@linux.com>
