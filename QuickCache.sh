#!/bin/bash
#set -x
USER="$(whoami)"							#checking who user is
echo "[+]Checking if user is root or not..."
if [ "$USER" == "root" ]; then
	echo "[+]User is root. Moving forward..."
	PING_OUT=$(ping -c4 $1 | awk '/---/,0' | wc -l)			#ping and send only 4 packets - awk will filter out other unnecessary information - wc -l will return how many lines the output consists of
	if [[ $PING_OUT -eq 3 ]]; then
		echo "[+]Updating before installing anything..."
		apt-get update > /dev/null
		echo "[+]Update completed"
		echo "[+]Checking if apache2 is installed or not..."
		CHECK="$(dpkg -l | grep apache2)"
		if [ -z "$CHECK" ]; then
			echo "[+]apache2 not installed."
			echo "[+]Installing apache2..."
			apt-get install apache2 > /dev/null
			echo "[+]apache2 installation completed."
		else
			echo "[+]apache2 is installed"
		fi
		echo "[+]Checking if varnish is installed or not..."
		CHECK="$(dpkg -l | grep varnish)"
		if [ -z "$CHECK" ]; then 
			echo "[+]varnish not installed."
			echo "[+]Installing varnish..."
			apt-get install varnish > /dev/null
			echo "[+]varnish installation completed."
		else
			echo "[+]varnish is installed."
		fi
		echo "[+]Configuring /etc/apache2/ports.conf..."
		PORTS=$(cat /etc/apache2/ports.conf)
		if [ -z "$PORTS" ]; then
			echo "[-]Error reading /etc/apache2/ports.config file. Please check if file is not empty."
		else
			sed -i 's/80/8080/g' /etc/apache2/ports.conf
			echo "[+]/etc/apache2/ports.conf file configured."
		fi
		echo "[+]Configuring /etc/apache2/sites-available/000-default.conf file"
		VIRTUAL_HOSTS=$(cat /etc/apache2/sites-available/000-default.conf)
		if [ -z "$VIRTUAL_HOSTS" ]; then
			echo "[-]Error reading /etc/apache2/sites-available/000-default.conf file. Please check if file is not empty"
		else
			sed -i 's/<VirtualHost *:80>/<VirtualHost *:8080>/g' /etc/apache2/sites-available/000-default.conf
			echo "[+]/etc/apache2/sites-available/000-default.conf file configured."
			echo "[+]Restarting apache2..."
			systemctl restart apache2
			echo "[+]apache2 restarted."
		fi
		echo "[+]Stopping varnish before making any changes"
		systemctl stop varnish
		echo "[+]Configuring /etc/varnish/default.vcl file..."
		DEFAULT=$(cat /etc/varnish/default.vcl)
		if [ -z "$DEFAULT" ]; then
			echo "[-]Error reading /etc/varnish/default.vcl file. Please check if file is not empty."
		else
			sed -i 's/127.0.0.1/'$1'/g' /etc/varnish/default.vcl
			echo "[+]/etc/varnish/default.vcl file configured."
		fi

		#Putting varnish on port 80
		echo "[+]Configuring /lib/systemd/system/varnish.service file..."
		VARNISH_SERVICE=$(cat /lib/systemd/system/varnish.service)
		if [ -z "$VARNISH_SERVICE" ]; then
			echo "[-]Error reading /lib/systemd/system/varnish.service file. Please check if file is not empty."
		else
			sed -i 's/6081/80/g' /lib/systemd/system/varnish.service
			echo "[+]/lib/systemd/system/varnish.service file configured."
			echo "[+]Reloading systemd..."
			systemctl daemon-reload > /dev/null
			echo "[+]Restarting varnish..."
			systemctl restart varnish > /dev/null
			echo "[+]Woosh! Finally configured! You're good to go fam :)"
		fi
	else
		echo "[-]Host not reachable."
	fi
else
	echo "[-]Root not found. Run script with sudo."
fi
#set +x
