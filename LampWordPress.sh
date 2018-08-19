#!/bin/bash
subscriptionname=<SubscriptionName>
location=westeurope # the azure zone you are working with
rootname=installwp # the name of all the veriable
dns_name="iab01" #increment me
wordpressmysqlrootpassword=<mysql root password>
wordpressmysqldbname=<wordpress mysql db name>
wordpressmysqldbusername=<wordpress mysql user name>
wordpressmysqldbpassword=<wordpress mysql db password>

resource_group_name=$rootname"rg"
vm_name=$rootname"vm"
fqdn_name=$dns_name"."$location".cloudapp.azure.com"
subscriptionid=$(az account list --output json --query "[?name=='$subscriptionname']|[0].id" | tr -d '"')
az account set --subscription $subscriptionid

az group create \
    --name $resource_group_name \
    --location $location \
    --subscription $subscriptionid

az group delete \
    --name $resource_group_name -y

[ -f ./cloud-init-web-server.yml ] && rm ./cloud-init-web-server.yml
cat >> ./cloud-init-web-server.yml <<EOF
#cloud-config
package_upgrade: true
packages:
 - apache2
 - mariadb-server  
 - mariadb-client
 - expect
 - software-properties-common
 - python-software-properties
 - [php7.0]
 - [libapache2-mod-php7.0]
 - [php7.0-common]
 - [php7.0-mbstring]
 - [php7.0-xmlrpc]
 - [php7.0-soap]
 - [php7.0-gd]
 - [php7.0-xml]
 - [php7.0-intl]
 - [php7.0-mysql]
 - [php7.0-cli]
 - [php7.0-mcrypt]
 - [php7.0-zip]
 - [php7.0-curl]
write_files:
  - path: /etc/apache2/sites-available/wordpress.conf
    content: |
      <VirtualHost *:80>
           ServerAdmin admin@example.com
           DocumentRoot /var/www/html/wordpress/
           ServerName $fqdn_name
           ServerAlias $fqdn_name
      
           <Directory /var/www/html/wordpress/>
              Options +FollowSymlinks
              AllowOverride All
              Require all granted
           </Directory>
      
           ErrorLog ${APACHE_LOG_DIR}/error.log
           CustomLog ${APACHE_LOG_DIR}/access.log combined
      
      </VirtualHost>
  - owner: www-data:www-data
  - owner: azureuser:azureuser
  - path: /tmp/SECURE_MYSQL
    content: |
      #!/bin/bash
      expect -c "
      set timeout 10
      spawn sudo mysql_secure_installation
      expect \"Enter current password for root (enter for none):\"
      send \"\r\"
      expect \"Set root password?\"
      send \"Y\r\"
      expect \"New password:\"
      send \"$wordpressmysqlrootpassword\r\"
      expect \"Re-enter new password:\"
      send \"$wordpressmysqlrootpassword\r\"
      expect \"Remove anonymous users?\"
      send \"Y\r\"
      expect \"Disallow root login remotely?\"
      send \"Y\r\"
      expect \"Remove test database and access to it?\"
      send \"Y\r\"
      expect \"Reload privilege tables now?\"
      send \"Y\r\"
      expect eof
      "
  - owner: azureuser:azureuser
  - path: /tmp/MYSQL_SCRIPT 
    content: |
      CREATE DATABASE $wordpressmysqldbname DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
      GRANT ALL ON $wordpressmysqldbname.* TO '$wordpressmysqldbusername'@'localhost' IDENTIFIED BY '$wordpressmysqldbpassword';
      FLUSH PRIVILEGES;
  - owner: azureuser:azureuser
  - path: /tmp/certbotinstall
    content: |
      #!/bin/bash
      sudo apt-get install software-properties-common python-software-properties -y
      echo "\r" | sudo add-apt-repository ppa:certbot/certbot
      sudo apt-get update -y
      sudo apt-get install python-certbot-apache -y
runcmd:
  - sed -i "s/Options Indexes FollowSymLinks/Options FollowSymLinks/" /etc/apache2/apache2.conf
  - systemctl stop apache2.service
  - systemctl start apache2.service
  - systemctl enable apache2.service
  - systemctl stop mysql.service
  - systemctl start mysql.service
  - systemctl enable mysql.service
  - /bin/bash /tmp/SECURE_MYSQL
  - systemctl restart mysql.service
  - mysql -u root -p$wordpressmysqlrootpassword < /tmp/MYSQL_SCRIPT
  - sed -i 's/^memory_limit = 128M/memory_limit = 256M/' /etc/php/7.0/apache2/php.ini
  - sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 100M/' /etc/php/7.0/apache2/php.ini
  - sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.0/apache2/php.ini
  - sed -i 's/^max_execution_time = 30/max_execution_time = 360/' /etc/php/7.0/apache2/php.ini
  - sed -i "s/^;date.timezone =$/date.timezone = \"Europe\/London\"/" /etc/php/7.0/apache2/php.ini
  - wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
  - tar -zxvf /tmp/latest.tar.gz -C /var/www/html
  - chown -R www-data:www-data /var/www/html/wordpress/
  - chmod -R 755 /var/www/html/wordpress/
  - service apache2 reload
  - a2ensite wordpress.conf
  - a2enmod rewrite
  - mv /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
  - sed -i "s/database_name_here/$wordpressmysqldbname/" /var/www/html/wordpress/wp-config.php
  - sed -i "s/username_here/$wordpressmysqldbusername/" /var/www/html/wordpress/wp-config.php
  - sed -i "s/password_here/$wordpressmysqldbpassword/" /var/www/html/wordpress/wp-config.php
  - /bin/bash /tmp/certbot
  - service apache2 restart
final_message: "The system is finally up, after $UPTIME seconds"
EOF

az vm create \
    --verbose \
    --resource-group $resource_group_name \
    --name $vm_name \
    --image UbuntuLTS \
    --size Standard_D2_v2 \
    --admin-username azureuser \
    --ssh-key-value ~/.ssh/id_rsa.pub \
    --custom-data ./cloud-init-web-server.yml  \
    --public-ip-address iabpublicip \
    --public-ip-address-allocation static \
    --public-ip-address-dns-name $dns_name \
    --subscription $subscriptionid

az vm open-port \
    --resource-group $resource_group_name \
    --name $vm_name \
    --port 80

az vm open-port \
    --resource-group $resource_group_name \
    --name $vm_name \
    --port 443 \
    --priority 1100
