#!/usr/bin/env bash

S3BUCKETNAME=ca-s3fs-bucket
S3BUCKETREGION=us-west-2
FTPUSERNAME=ftpuser1
FTPPASSWORD=password

# =========================

sudo yum -y update

sudo yum -y install \
jq \
automake \
openssl-devel \
git \
gcc \
libstdc++-devel \
gcc-c++ \
fuse \
fuse-devel \
curl-devel \
libxml2-devel

# =========================

git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/

./autogen.sh
./configure

make
sudo make install

# =========================

sudo adduser $FTPUSERNAME
echo "$FTPUSERNAME:$FTPPASSWORD" | sudo chpasswd

# =========================

sudo mkdir /home/$FTPUSERNAME/ftp
sudo chown nfsnobody:nfsnobody /home/$FTPUSERNAME/ftp
sudo chmod a-w /home/$FTPUSERNAME/ftp
sudo mkdir /home/$FTPUSERNAME/ftp/files
sudo chown $FTPUSERNAME:$FTPUSERNAME /home/$FTPUSERNAME/ftp/files

# =========================

sudo yum -y install vsftpd
sudo mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak

sudo EC2_PUBLIC_IP=`curl -s ifconfig.co` bash -c 'cat > /etc/vsftpd/vsftpd.conf << EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
chroot_local_user=YES
listen=YES
pam_service_name=vsftpd
tcp_wrappers=YES
user_sub_token=\$USER
local_root=/home/\$USER/ftp
pasv_min_port=40000
pasv_max_port=50000
pasv_address=$EC2_PUBLIC_IP
userlist_file=/etc/vsftpd.userlist
userlist_enable=YES
userlist_deny=NO
EOF'

sudo cat /etc/vsftpd/vsftpd.conf

# =========================

echo $FTPUSERNAME | sudo tee -a /etc/vsftpd.userlist

# =========================

sudo systemctl start vsftpd
sudo systemctl status vsftpd

# =========================

EC2METALATEST=http://169.254.169.254/latest
EC2METAURL=$EC2METALATEST/meta-data/iam/security-credentials/
EC2ROLE=`curl -s $EC2METAURL`
echo "EC2ROLE: $EC2ROLE"
sudo /usr/local/bin/s3fs $S3BUCKETNAME \
-o use_cache=/tmp,iam_role="$EC2ROLE",allow_other /home/$FTPUSERNAME/ftp/files \
-o url="https://s3-$S3BUCKETREGION.amazonaws.com" \
-o nonempty

# =========================

ps -ef | grep  s3fs

# =========================

echo finished!!