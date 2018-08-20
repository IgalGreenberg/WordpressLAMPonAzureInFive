# WordpressLAMPonAzureInFive
Get an Azure VM up and running with WordPress on LAMP in five minutes. The VM would have Ubuntu 16, Apache 2, MariaDB, PHP 7.0 and latest wordpress.
I have used several websites to create this entry.  The biggest thanks goes to:
1. https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-lemp-stack
2. https://websiteforstudents.com/install-wordpress-on-ubuntu-16-04-lts-with-apache2-mariadb-and-php-7-1-support/

There are so many more to thank.  

Install prerequisites:
1. This install uses bash.  If using windows use Bash on Windows: https://docs.microsoft.com/en-us/windows/wsl/install-win10.
2. Azure cli: Install the Azure cli api: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

Install wordpress on lamp:
Launch bash:
```bash
az login
git clone https://github.com/IgalGreenberg/WordpressLAMPonAzureInFive.git
cd WordpressLAMPonAzureInFive/
```
Edit LampWordPress.sh and enter strong values for:
- subscriptionname="Visual Studio Enterprise"
- location=westeurope # the azure zone you are working with
- rootname=installwp # the name of all the veriable
- dns_name="iab01" #increment me
- wordpressmysqlrootpassword=<mysql root password>
- wordpressmysqldbname=<wordpress mysql db name>
- wordpressmysqldbusername=<wordpress mysql user name>
- wordpressmysqldbpassword=<wordpress mysql db password>

```bash
sh LampWordPress.sh
```

You now have a LAMP server with Wordpress on Azure!
You can check the install by reviewing /var/log/cloud-init-output.log

If you need an SSL certificate for your new server:
back in bash:
```bash
publicip=$(az vm list-ip-addresses -n $vm_name --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv)
echo "sudo certbot --apache -m \"admin@$fqdn_name\" -d \"$fqdn_name\""
ssh azureuser@$fqdn_name
# run the echo command on the remote server
# next you can configure a monthly scheduled SSL certificate update:
crontab -e
0 0 1 * * /usr/bin/letsencrypt renew >> /var/log/letsencrypt-renew.log
sudo service cron restart
```

Hopefully this script provided you with a VM on Azure in five minutes.  Do let me know if this works for you.
In case you are using a custom DNS name this would be a good time to setup your DNS using your public IP (or a DNS Zone in Azure).  Once doing that do update the FQDN entry in /etc/apache2/sites-available/wordpress.conf.  Update the fqdn_name variable and run certbot again as above.
