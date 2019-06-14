#!/bin/bash
# shellcheck source=/dev/null
# shellcheck disable=SC2102
# shellcheck disable=SC1020
# shellcheck disable=SC1035
RUNAS="" # A variable to determine if we're running as the root user or not
USER="$(whoami)"
echo "BEFORE PROCEEDING ANY FURTHER, PLEASE NOTE THE FOLLOWING:"
echo "1) This script is in early development and lacks a lot of checking."
echo "2) Make ABSOLUTELY SURE that your current directory is /root/."
echo "3) A virtual environment within Python WILL NOT be used. Make sure this server is dedicated for the bot ONLY for security reasons."
echo "4) This script ONLY works on Debian 9 Stretch. There are currently no plans to support other platforms."
read -pr "If you've read the understand the above, press ENTER"

# Let's check to see who we're running as
if [ $UID == "0" ] ; then
	RUNAS="root"
else
	RUNAS="nonroot"
fi

# Check if we have the sudo command

if [ -z "$(command -v sudo)" ] && [ "$RUNAS" == "nonroot" ] ; then
	echo "ERROR! It looks like the sudo package is not installed."
	echo "Please switch to the root user and install it by running:"
	echo "apt update && apt install sudo -y"
	exit 1
fi

# Check if we've already installed Red
if [ -f "$HOME/.phase1" ] && [ -f "$HOME/.phase2" ] && [ -f "$HOME/.phase3" ] && [ -f "$HOME/.installed" ] ; then
	echo "Looks like you've already installed Red."
	echo "Goodbye!"
	exit 1
fi

if [ ! -f "$HOME/.phase1" ] ; then

	# BEGIN PHASE 1
	echo "Now installing packages...."

	if [ "$RUNAS" == "nonroot" ] ; then
		sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
		libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
		xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git unzip default-jre
	else
		apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
		libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
		xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git unzip default-jre
	fi

	# As a pre-emptive measure, let's put some pieces into our .bashrc:

	{
	 echo "export PATH=\"$HOME/.pyenv/bin:$PATH"\"
	 echo "eval \"$(pyenv init -)"\"
	 echo "eval \"$(pyenv virtualenv-init -)"\"
	 echo "export PATH=\"$HOME/.local/bin:$PATH"\" 
	} >>"$HOME/.bashrc"
	source "$HOME/.bashrc"

	# Next, let's install pyenv

	if [ "$RUNAS" == "nonroot" ] ; then
		sudo curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
	else
		curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
	fi
fi
# END PHASE 1
touch "$HOME/.phase1"
# Now let's run the next phase
if [ ! -f "$HOME/.phase2" ] ; then
	pyenv install 3.7.2 -v
	pyenv global 3.7.2

	echo "Now it's time to select the type of bot you want:"
	echo "1) Install WITHOUT MongoDB support"
	echo "2) Install WITH MongoDB support"
	read -pr "Please enter your choice: " bottype
	if [ "$bottype" == "1" ] ; then
		python3.7 -m pip install -U Red-DiscordBot --user
	elif [ "$bottype" == "2" ] ; then
		python3.7 -m pip install -U Red-DiscordBot[mongo] --user
	else
		echo "INVALID CHOICE!"
		echo "Exiting...."
		exit 1
	fi
	# END OF PHASE 2
	touch "$HOME/.phase2"
	echo "We're done for now. Please log out of your session and log back in."
	echo "After you've logged back in, run \"redbot-setup"\"
	echo "If this doesn't work, please run \"$HOME/.local/bin/redbot-setup"\"
	echo "Once you've finished with the initlal setup, run this script one final time."
	exit
fi
# Now we'll begin the final phase

if [ ! -f "$HOME/.phase3" ] ; then
	echo "Now let's create our service file"
cat /tmp/red <EOF
[Unit]
Description=%I redbot
After=multi-user.target

[Service]
ExecStart=$HOME/.pyenv/versions/3.7.2/bin/python $HOME/.local/bin/redbot %I --no-prompt
User=$USER
Group=$USER
Type=idle
Restart=always
RestartSec=15
RestartPreventExitStatus=0
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
	sudo cp /tmp/red /etc/systemd/system/red@.service
	read -pr "What is the name of your bot's instance?: " instancename
	echo "Putting in the rest of the pieces to auto-start bot instance named $instancename
	sudo systemctl start red@$instancename
	sudo systemctl enable red@$instancename
	echo "Done!"
	touch "$HOME/.installed"
	echo "Rebooting in 10 seconds...."
	sleep 10s
	sudo reboot

fi
