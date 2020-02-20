## About
This repository will install Nextcloud on a CentOS 7 VPS with Redis, Percona Server, Let's Encrypt SSL, and an Nginx reverse proxy. These services are all running as Docker containers managed by Docker Compose.

It also includes automated backups which can optionally be uploaded to an S3 bucket.

## Pre-requisites and assumptions
- A fresh install of CentOS 7 on a VPS.
- The instance is provisioned with at least 2 CPUs and 1G of RAM.
- You have a domain that is pointing to the instance.

Below is a summary of my set up in AWS, but further details are outside the scope of this guide...
- A t3a.micro EC2 with Elastic IP assigned to it.
- In Route53, a CNAME record (nextcloud.mydomain.com).
- A second EBS volume attached and mounted to /var/lib/docker.
- Security Groups and firewall configured to restrict access to only necessary ports.

## Install Docker
Install the EPEL repository and update the server
```
sudo yum install -y epel-release

sudo yum update
```
Install Docker Community Edition repositories to install Docker, then install Docker Compose
```
sudo curl https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker.repo

sudo yum install -y docker-ce

sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
```
Start Docker, enable Docker to start at boot
```
sudo systemctl start docker.service ; sudo systemctl enable docker.service
```
Add your user to the `docker` group to be able to execute `docker` commands
```
sudo usermod -aG docker <username>
```
You must now reboot to apply the `docker` group to your user
```
sudo reboot now
```

## Configure your cloud
Install Git and clone this `cloud` repository
- _Critical note: The entirety of this deployment is dependent upon this repository existing in `/opt/cloud`. If you choose another location, you will break all the things._
```
sudo yum install -y git

sudo mkdir /opt/cloud ; sudo chown <username>.<username> -R /opt/cloud

git clone https://github.com/code-red-panda/cloud.git /opt/cloud/

cd /opt/cloud
```
Copy the environment variables template to `.env`
```
cp template.env .env
```
Now edit the file with your settings
```
vi .env

# VERSIONS
LETSENCRYPT_VERSION=v1.12
REDIS_VERSION=5.0.6
PERCONA_VERSION=5.7.26
NEXTCLOUD_VERSION=17.0.1

# MySQL
MYSQL_ROOT_PASSWORD=RootPass123^ <--- replace with a strong passphrase
MYSQL_PASSWORD=UserPass123^  <--- replace with a different strong passphrase
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud
MYSQL_HOST=percona-server

# LETENCRYPT
DOMAIN=your.domain.tld  <--- replace with your CNAME
EMAIL=you@domain.tld <--- replace with your email

# REDIS
REDIS_HOST=redis
```

## Launch the containers
Create the Docker network for the containers to communicate
```
docker network create nextcloud_network
```
We're ready, launch the containers!
```
docker-compose up -d
```
Once done, check that all five containers were created OK
```
docker ps
CONTAINER ID        IMAGE                                          COMMAND                  CREATED              STATUS              PORTS                                      NAMES
fefc84512bb5        nextcloud:17.0.1                               "/entrypoint.sh apac…"   About a minute ago   Up About a minute   80/tcp                                     nextcloud
e6273736b58e        jrcs/letsencrypt-nginx-proxy-companion:v1.12   "/bin/bash /app/entr…"   About a minute ago   Up About a minute                                              letsencrypt
51aec1d4dd88        percona:5.7.26                                 "/docker-entrypoint.…"   About a minute ago   Up About a minute   3306/tcp                                   percona-server
c70f430e152b        jwilder/nginx-proxy:alpine                     "/app/docker-entrypo…"   About a minute ago   Up About a minute   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   nginx
c8c77c648b2d        redis:5.0.6                                    "docker-entrypoint.s…"   About a minute ago   Up About a minute   6379/tcp                                   redis
```
Copy an additional Nextcloud configuration into place and restart the container to apply
```
sudo cp data/nextcloud/nextcloud.config.php /var/lib/docker/volumes/cloud_nextcloud/_data/config/

docker restart nextcloud
```

## Your very own cloud
Wait 5 minutes for the SSL certificates, then visit: https://your.domain.tld

You will be prompted to create an `admin` account.

Further Nextcloud configuration and administration is outside the scope of this guide, but you can get started here:

https://docs.nextcloud.com/server/latest/admin_manual/

https://docs.nextcloud.com/server/latest/user_manual/

Nextcloud also offers desktop clients to sync files to your computer, as well as a phone app:

https://nextcloud.com/clients/

Security is on you as the administrator. You should read the Nextcloud hardening guidelines and also scan your site for vulnerabilities:

https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html

https://scan.nextcloud.com/

## Troubleshooting
If you're having trouble, review the logs for all Docker services
```
cd /opt/cloud

docker-compose logs
```
To only view logs for a particular container, pass in the service name. Ex:
```
docker-compose logs nextcloud
```

## Backups
Note: The backup script does not yet contain the encryption, S3 upload, or backup purging.

Download and run a tool to help generate entropy for our GPG keys
```
sudo yum install -y rng-tools

sudo rngd -r /dev/urandom
```
Become `root` and generate GPG keys for encryption
- _Note: The default GPG settings are OK_
```
sudo -i

gpg --gen-key
...
<use defaults>
...
Real name: Nextcloud Backup Encryption
Email address: your@domain.tld
Comment:
...
You need a Passphrase to protect your secret key.
<enter a strong passphrase and keep it in your password manager>
...
```
Logout from `root` back to your user, then install Mydumper
```
logout

sudo yum install -y https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el7.x86_64.rpm
```
For Mydumper to connect to Percona Server, copy the `.my.cnf` to `root`'s homedir
```
cd /opt/cloud

sudo cp data/backup/dot-my.cnf /root/.my.cnf
```
Get the Docker assigned IP of your Percona Server container for use in the next step
```
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' percona-server
```
Now edit the `.my.cnf` to update it with your IP and MySQL `root` password
```
sudo vi /root/.my.cnf

[client]
user=root
password=[MySQL root's password from .env] <--- update
host=[docker percona-server IP] <--- update
```
Copy the backup cron into place
```
sudo cp data/backup/nextcloud_crons /etc/cron.d/
```
Now edit the cron's `MAILTO` with your email address
```
sudo vi /etc/cron.d/nextcloud_crons

MAILTO=you@domain.tld
...
```
That's it, now backups will automatically run every 2 hours. You can run one manually to make sure it completes OK.
```
sudo sh /opt/cloud/data/backup/nextcloud_backup.sh
2020-01-26 00:51:57 UTC INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ START ]
2020-01-26 00:51:57 UTC INFO:: Putting Nextcloud into maintenance mode...
2020-01-26 00:51:58 UTC INFO:: Creating backup directory /backups/2020-01-26_00-51-UTC...
2020-01-26 00:51:58 UTC INFO:: Tar'ing Docker volumes /var/lib/docker/volumes/* /opt/cloud/data/* /opt/cloud/.env /root/.my.cnf...
2020-01-26 00:52:12 UTC INFO:: Taking Mydumper backup...
2020-01-26 00:52:13 UTC INFO:: Taking Nextcloud out of maintenance mode...
2020-01-26 00:52:13 UTC INFO::>>>>>>>>>>>>>>>>>> BACKUP STATUS: [ COMPLETED ]
```
Once the backups run from cron, you will be able to review the logs here
```
sudo less /var/log/nextcloud/backup.log
```

# Restore
Steps coming soon.
