#!/usr/bin/env bash

##################################################################
#
# Install script for installing boot2docker for power architecture
#
##################################################################

#set -x

VERSION="v1.13.1"
ISOPATH="$HOME/.docker/machine"
ISOFILE="boot2docker-${VERSION}.iso"
# TO-DO : Update with proper link once we get the binaries out
REPOURL="http://ftp.unicamp.br/pub/ppc64le/boot2docker"
INSTALLBIN="/usr/local/bin"
OS=$(uname -s)
DISTRO=""

getdistro()
{
	if [[ ${OS} == "Darwin" ]]; then
		DISTRO=${OS}
	fi

	if [ -f /etc/lsb-release ]; then
		. /etc/lsb-release
		DISTRO=$DISTRIB_ID
	elif [ -f /etc/debian_version ]; then
		DISTRO="Debian"
	elif [ -f /etc/fedora-release ]; then
                DISTRO="Fedora"
	elif [ -f /etc/redhat-release ]; then
		DISTRO="Redhat"
	fi
}

# Check prereq to run this script
precheck()
{
	echo "TO-DO: Checking Prereq.....";
	precheck_common
	if [[ ${OS} == "Linux" ]]; then
		precheck_linux
	elif [[ ${OS} == "Darwin" ]]; then
		precheck_darwin
	else
		echo "Unspported ${OS}, exiting precheck"
	fi
}

suggest_docker-machine()
{
	echo "Please refer instructions from https://docs.docker.com/machine/install-machine/ to install docker-machine"
        while true; do
                read -p "Do you want me to install for you? " ans
                case $ans in
                        [Yy]* ) install_docker-machine;echo "PASS";return;;
                        [Nn]* ) return;;
                        * ) echo "Please answer yes or no.";;
                esac
        done
}

install_docker-machine()
{
	case ${OS} in
                Linux ) curl -s -L https://github.com/docker/machine/releases/download/v0.9.0/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine &&
			chmod +x /tmp/docker-machine &&
			sudo cp /tmp/docker-machine /usr/local/bin/docker-machine
			return;;
                Darwin ) curl -s -L https://github.com/docker/machine/releases/download/v0.9.0/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine && \
			chmod +x /usr/local/bin/docker-machine
			return;;
                * ) echo "I don't know how to install for this distro ${OS}...";exit 1;;
        esac

}

suggest_qemu-system-ppc64()
{
	echo -e "\nFor Linux:\nInstall qemu-system-ppc package\n\n"
	echo -e "For Mac:\nFollow instructions from https://github.com/psema4/pine/wiki/Installing-QEMU-on-OS-X and install the qemu\n"

	while true; do
		read -p "Do you want me to install for you? " ans
		case $ans in
			[Yy]* ) install_qemu-system-ppc64;return;;
			[Nn]* ) return;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

install_qemu-system-ppc64()
{
	getdistro
	case "$DISTRO" in
		"Darwin" ) brew install qemu; return;;
		"Fedora" ) sudo dnf install -y qemu-system-ppc; return;;
		"Ubuntu" ) sudo apt-get install -y qemu-system-ppc;;
#		"Redhat" ) return;;
		* ) echo "I don't know how to install for this distro : ${DISTRO}";return 1;;
	esac
}

suggest_libvirtd()
{
        echo -e "Refer link: https://libvirt.org/compiling.html for more information\n"

        while true; do
                read -p "Do you want me to install for you? " ans
                case $ans in
                        [Yy]* ) install_libvirtd;return;;
                        [Nn]* ) return;;
                        * ) echo "Please answer yes or no.";;
                esac
        done
}

suggest_brew()
{
	echo -e "Refer link: https://brew.sh/ for installation\n"

        while true; do
                read -p "Do you want me to install for you? " ans
                case $ans in
                        [Yy]* ) install_brew;return;;
                        [Nn]* ) return;;
                        * ) echo "Please answer yes or no.";;
                esac
        done
}

install_brew()
{
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}


install_libvirtd()
{
        getdistro
        case "$DISTRO" in
                "Fedora" ) sudo dnf install -y libvirt;sudo systemctl start libvirtd; return;;
                "Ubuntu" ) sudo apt-get install -y libvirt-bin; sudo systemctl start libvirtd; return;;
#               "Redhat" ) return;;
                * ) echo "I don't know how to install for this distro...";return 1;;
        esac
}


precheck_cmd()
{
	echo "Checking for $1...."
        read CMDRET CMDPATH < <(check_cmd_installed $1)
	if [[ $CMDRET != 0 ]]; then
		echo "Command \"$1\" not found, please install it to proceed further."
		if [[ -n "$(type -t suggest_$1)" ]]; then
			suggest_$1
			if [[ $? == 0 ]]; then
				return
			fi 
		fi
		exit 1
	else
		echo "Found at $CMDPATH"
	fi
}

precheck_common()
{
	echo "common checks...."

	prereq_cmds=( curl docker-machine )
	for i in "${prereq_cmds[@]}"
	do
		precheck_cmd $i
	done 
}

precheck_linux()
{
	linux_prereq_cmds=( md5sum libvirtd qemu-system-ppc64 )
        for i in "${linux_prereq_cmds[@]}"
        do
                precheck_cmd $i
        done

}

precheck_darwin()
{
	darwin_prereq_cmds=( brew md5 qemu-system-ppc64 )
        for i in "${darwin_prereq_cmds[@]}"
        do
                precheck_cmd $i
        done

	brew cask search tuntap
	if [[ $? != 0 ]]; then
		echo "Installing tuntap..."
		brew cask install tuntap
		if [[ $? != 0 ]]; then
			echo "Failed to install tuntap, please fix the above error and run this script one more time.!"
			exit 1
		fi
		echo "done..."
	fi
}

# Check for a command in the path and returns(status, path)
check_cmd_installed()
{
	CMD_PATH=$(command -v $1)
	echo "$? $CMD_PATH"
}

download_boot2docker()
{
	mkdir -p ${ISOPATH}
	curl -s -f ${REPOURL}/iso/${ISOFILE} -o ${ISOPATH}/${ISOFILE}
	if [[ $? != 0 ]]; then
		echo -e "\nFailed to pull the boot2docker iso from repository - ${REPOURL}/iso/${ISOFILE}"
		exit 1
	fi
}

precheck

#echo "Checking for docker-machine-driver-qemu"
#read CMDRET CMDPATH < <(check_cmd_installed docker-machine-driver-qemu)

#if [[ ${CMDRET} != 0 ]]; then
	#echo "Unable to find docker-machine-driver-qemu in the path, pulling it from the repository"
	echo "Pulling docker-machine-driver-qemu from repo...."
	case "${OS}" in
		"Linux")  DRIVER="${REPOURL}/docker-machine-driver-qemu/linux/docker-machine-driver-qemu"
			  ;;
		"Darwin") DRIVER="${REPOURL}/docker-machine-driver-qemu/darwin/docker-machine-driver-qemu"
			  ;;
		*) echo "${OS} does not support"
		   exit 1
		   ;;
	esac
	curl -s -f ${DRIVER} -o /tmp/docker-machine-driver-qemu
	chmod +x /tmp/docker-machine-driver-qemu
	sudo cp /tmp/docker-machine-driver-qemu ${INSTALLBIN}/docker-machine-driver-qemu
	if [[ $? != 0 ]]; then
		echo "Failed to pull docker-machine-driver-qemu from ${DRIVER}"
	fi
#else
#	echo "Found at ${CMDPATH}"
#fi

if [[ ! -f ${ISOPATH}/${ISOFILE} ]]; then
	echo "${ISOPATH}/${ISOFILE} not found, pulling it from repository....."
	download_boot2docker
fi

echo "Checking checksum..."
TEMPDIR=$(mktemp -d)
curl -s -f ${REPOURL}/iso/MD5SUM -o ${TEMPDIR}/MD5SUM
pushd ${ISOPATH} > /dev/null 2>&1
if [[ ${OS} == "Linux" ]]; then
	grep ${ISOFILE} ${TEMPDIR}/MD5SUM | md5sum -c
	if [[ $? != 0 ]]; then
		echo "Checksum failed, downloading again the iso..."
		download_boot2docker
	fi
elif [[  ${OS} == "Darwin" ]]; then
	MD5CKSUM=$(md5 ${ISOFILE} | cut -d= -f2| sed -e 's/^ *//g;s/ *$//g')
	GOLD_MD5_CKSUM=$(grep ${ISOFILE} ${TEMPDIR}/MD5SUM | cut -d " " -f1|sed -e 's/^ *//g;s/ *$//g')
	if [[ $MD5CKSUM != $GOLD_MD5_CKSUM ]]; then
        	echo "Checksum failed, downloading again the iso..."
	        download_boot2docker
	fi
else
	echo -e "Failed to check MD5 checksum: Unsupported OS : ${OS}\n"
	exit 1
fi

ln -s -f ${ISOPATH}/${ISOFILE} ${ISOPATH}/boot2docker.iso

echo -e "\n\nNow run the following command to start boot2docker for ppc64le:"
echo -e "\ndocker-machine -D create -d qemu --qemu-boot2docker-url=${ISOPATH}/boot2docker.iso --qemu-memory <RAM> --qemu-arch ppc64le <NAME>\n\nRAM: should be in MB, mininum is 2048"
