#!/bin/bash

NODE="${2}"
STORAGE="192.168.46.14"
NFS_REPO="/vagrant/sles-nfs.tgz"
ISO_FILE="SLE-12-SP4-Server-DVD-x86_64-GM-DVD1.iso"
REPO_FILE="/etc/zypp/repos.d/SLES12.repo"
SUSE_BASE="/img/base/suse/x86_64"
OUT_FILE="/etc/deployment.auto"
VM1="vm1"
VM2="vm2"
C_USER="vagrant"

local_config() {

if [[ ! -f ${NFS_REPO} ]]
then
   echo "---> NFS Repository do not exist..."
   exit 1
fi
# Checking if /home/vagrant/nfs folder exists 
if [[ ! -d /home/vagrant/nfs ]]
   then 
      sudo mkdir -p /home/vagrant/nfs
fi
sudo cp /vagrant/sles-nfs.tgz /home/vagrant/nfs
sudo tar xvf /home/vagrant/nfs/sles-nfs.tgz -C /home/vagrant/nfs
sudo cp /home/vagrant/nfs/mini-repo.repo /etc/zypp/repos.d/sles-nfs.repo
sudo zypper clean
sudo zypper refresh
sudo zypper install -y nfs-client


if [[ ! -d /nfs/software_repo/suse ]]
then
   echo "---> Create directory structure"
   sudo mkdir -p /nfs
   sudo chown -R nobody:nogroup /nfs
   #sudo mount ${STORAGE}:/nfs /nfs
   #sudo mount ${STORAGE}:/nfs/software_repo /nfs/software_repo
fi

sudo echo '192.168.46.12    vm1' | sudo tee -a /etc/hosts
sudo echo '192.168.46.13    vm2' | sudo tee -a /etc/hosts
sudo echo '192.168.46.14    storage' | sudo tee -a /etc/hosts
echo "---> Mounting NFS FileSystems"

cat /proc/mounts | grep nfs >> /dev/null
if [[ ${?} = 1 ]]
then
   #sudo mount -t nfs storage:/nfs /nfs
   sudo mount -t nfs storage:/nfs /nfs
   #sudo mount -t nfs storage:/img/base /nfs/suse
   echo "---> Adding fstab entries"
   #sudo echo "storage:/nfs  /nfs nfs rw,relatime,vers=3,rsize=262144,wsize=262144,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,nolock 0 0" >> /etc/fstab
   sudo echo "storage:/nfs  /nfs nfs rw,relatime,vers=3,rsize=262144,wsize=262144,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,nolock 0 0" >> /etc/fstab
   #sudo echo "storage:/img/base  /nfs/software_repo/suse nfs rw,relatime,vers=3,rsize=262144,wsize=262144,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,nolock 0 0" >> /etc/fstab
fi

cat /proc/mounts | grep suse >> /dev/null
if [[ ${?} = 1 ]]
then
   sudo mount -t nfs storage:/img/base /nfs/software_repo/suse
   sudo echo "storage:/img/base  /nfs/software_repo/suse nfs rw,relatime,vers=3,rsize=262144,wsize=262144,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,nolock 0 0" >> /etc/fstab
fi
echo "---> Adding Software Repository"
if [[ ! -f /etc/zypp/repos.d/SLES12.repo ]]
then
   echo "[SLES]" > /etc/zypp/repos.d/SLES12.repo
   echo "name=SLES12" >> /etc/zypp/repos.d/SLES12.repo
   echo "enabled=1" >> /etc/zypp/repos.d/SLES12.repo
   echo "baseurl=file:///nfs/software_repo/suse/suse/x86_64" >> /etc/zypp/repos.d/SLES12.repo
   echo "type=plaindir" >> /etc/zypp/repos.d/SLES12.repo
   echo "gpgcheck=0" >> /etc/zypp/repos.d/SLES12.repo
   sudo zypper clean
   sudo zypper refresh
fi



echo "Done"
#if [[ ! -f /vagrant/${NODE}_keys.tar.gz ]]
#then 
#   echo "---> Server Key not exists. Stoping now"
#   exit 1
#fi
#cp /vagrant/${NODE}_keys.tar.gz /home/vagrant/.ssh/
#tar xvf /home/vagrant/.ssh/${NODE}_keys.tar.gz -C /home/vagrant/.ssh/





}

remote_config() {


     sudo scp -p ./deployment.sh ${NODE}:/home/vagrant/deployment.sh
     ssh vagrant@${NODE} "sudo /home/vagrant/deployment.sh local"
     
     

}
#************************ SERVER CONFIG ************************************
server_config() {

if [[ -f ${OUT_FILE} ]]
then
   echo "Automatic Deployment already Done. Exits..."
   exit 0
fi
echo "---> Configuring server side..."

if [[ ! -f ${ISO_FILE} ]]
then
   echo "---> ISO File not fount in directory..."
   exit 1
fi
# Checking the existence of /img directory

if [[ ! -d /img ]]
then  
   sudo mkdir -p /img/base
fi    


echo "---> Mounting STORAGE Disk"
cat /proc/mounts | grep sdb > /dev/null
if [[ ${?} = 1 ]]
then
   echo "---> Create LVM Disks"
   sudo pvcreate /dev/sdb
   sudo vgcreate storage_vg /dev/sdb
   sudo lvcreate -l 100%FREE -n storage_lv storage_vg
   echo "---> Create FileSystem"
   sudo mkfs -t ext4 /dev/storage_vg/storage_lv
   echo "---> Mounting filesystem"
   sudo mount -t ext4 /dev/storage_vg/storage_lv /img/base
   echo "---> Adding fstab entries"
   sudo echo "/img/base        *(rw,sync,no_subtree_check,insecure)" >> /etc/exports
   sudo echo "/nfs         *(rw,sync,no_subtree_check,insecure)" >> /etc/exports
   #sudo exportfs -a
fi

# Checking the existence of /nfs directory
if [[ ! -d /nfs/software_repo/suse ]]
then  
  echo "---> Create NFS Directory Structure"
  sudo mkdir -p /nfs/software_repo
  sudo mkdir -p /nfs/software_repo/suse
  sudo mkdir -p /nfs/share
  sudo mkdir -p /nfs/logs
  sudo chown -R nobody:nogroup /nfs
  echo "Done..."
fi


echo "---> Copy ISO File to /img Directory"
sudo cp /vagrant/${ISO_FILE} /img
echo "---> Mounting ISO File"
sudo mount -o loop /img/${ISO_FILE} /img/base
if [[ "${?}" = 0 ]]
then 
  echo "Succesfully mounted ISO file"
fi
echo "---> Create repository file"
sudo touch ${REPO_FILE}
sudo echo "[SLES]" >> ${REPO_FILE}
sudo echo "name=SLES12" >> ${REPO_FILE}
sudo echo "enabled=1" >> ${REPO_FILE}
sudo echo "autorefresh=0"
sudo echo "baseurl=file://${SUSE_BASE}" >> ${REPO_FILE}
sudo echo "type=plaindir" >> ${REPO_FILE}
sudo echo "gpgcheck=0" >> ${REPO_FILE}
sudo zypper refresh
sudo echo "/img/SLE-12-SP4-Server-DVD-x86_64-GM-DVD1.iso /img/base iso9660 loop,ro,auto 0 0" >> /etc/fstab
echo "---> Installing NFS server..."
sudo zypper install -n nfs-kernel-server
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo systemctl enable nfsserver.service
sudo systemctl start nfsserver.service
sudo chown nobody:nogroup /nfs
sudo exportfs -a
#echo "/nfs        *(rw,sync,no_subtree_check,insecure)" >> /etc/exports
#sudo exportfs
#sudo echo '192.168.46.12    vm1' | sudo tee -a /etc/hosts
#sudo echo '192.168.46.13    vm2' | sudo tee -a /etc/hosts
#sudo echo '192.168.46.14    storage' | sudo tee -a /etc/hosts

#echo "---> Copy Local SSH Key"
#if [[ ! -f /vagrant/storage_keys.tar.gz ]]
#then 
#   echo "---> Server Key not exists. Stoping now"
#   exit 1
#fi
#cp /vagrant/storage_keys.tar.gz /home/vagrant/.ssh/
#tar zxvf /home/vagrant/.ssh/storage_keys.tar.gz -C /home/vagrant/.ssh/
#sudo scp ~/.ssh/id_rsa.pub ${VM2}:~/.ssh/authorized_keys
sudo touch ${OUT_FILE}

}

if [[ "${UID}" -ne 0 ]]
then
   echo "Please run this script with root priviledges"
   exit 1
fi





if [[ "${1}" = server ]]
then
   server_config


elif [[ "${1}" = remote ]]
then  
  echo "---> Checking Connectivity to ${NODE}..."
  #ping -c 3 ${NODE} &> /dev/null
  #if [[ "${?}" = 1 ]]
  #   then
  #      echo "---> Starting remote configuration of ${NODE}"
   remote_config
   #fi

elif [[ "${1}" = local ]]
then   
   local_config
fi



if [[ "${#}" -lt 1 ]]
then
   echo "Please supply the Virtual Machine name/ip"
   exit 1
fi
