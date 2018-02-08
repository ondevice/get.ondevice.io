#!/bin/bash
#
# installs the ondevice client
#
# On Debian based systems, this'll use the repo.ondevice.io/debian/ package repository
# On macOS, it'll use homebrew if available
# everywhere else, it'll detect the OS and architecture and download the matching
# `ondevice` binary.
#
# TODO: add RPM repository
#

set -e

# return 0 if running on a debian based distribution
_useApt() {
	[ -e /etc/apt/sources.list ]
	return $?
}

# sets the "$OS" variable
_detectOS() {
	if [ -n "$OS" ]; then
		return 0
	fi

	if uname | grep -iq darwin ; then
		OS=macos
	elif uname | grep -iq linux ; then
		OS=linux
	else
		echo ------------ >&2
		echo "Couldn't detect your OS (got '$(uname)')" >&2
		echo "You can specify one manually by setting the \$OS variable to 'macos' or 'linux'" >&2
		echo ------------ >&2
		exit 1
	fi
}

# sets the "$ARCH" variable
_detectArch() {
	if [ -n "$ARCH" ]; then
		return 0
	fi

	if uname -m | grep -iq x86_64; then
		ARCH=amd64
	elif uname -m | grep -iq i.86; then
		ARCH=i386
	elif uname -m | grep -qwe 'armv[67]l'; then
		ARCH=armhf
	else
		echo ------------ >&2
		echo "Couldn't detect your system architecture (got '$(uname -m)')" >&2
		echo "You can specify one manually by setting the \$ARCH variable to 'i386', 'amd64' or 'armhf'" >&2
		echo ------------ >&2
		exit 1
	fi
}



addAptKey() {
	curl -sSL https://repo.ondevice.io/ondevice.key | apt-key add -
}

addAptRepo() {
	REPO_FILE=/etc/apt/sources.list.d/ondevice.list
	if [ -f "$REPO_FILE" ]; then
		echo "-- '$REPO_FILE' already exists, won't overwrite" >&2
		return 0
	fi

	echo "-- writing '$REPO_FILE'" >&2
	echo "deb http://repo.ondevice.io/debian stable main" > "$REPO_FILE"
}

installDebian() {
	addAptRepo
	addAptKey

	echo '-- installing ondevice .deb package' >&2
	apt-get update || true
	apt-get install -y ondevice

	DEVICE_MSG="install the 'ondevice-daemon' package and follow the instructions."
}

installHomebrew() {
	echo '-- install ondevice using macOS homebrew' >&2
	brew install ondevice/tap/ondevice

	DEVICE_MSG="run 'brew services start ondevice-daemon'"
}

_detectOS
_detectArch

# install on debian based systems
if _useApt; then
	installDebian
	exit 0
elif [ "$OS" == macos -a -x /usr/local/bin/brew ]; then
	installHomebrew
else
	echo "-- installing ondevice on $OS - $ARCH" >&2

	VERSION="$(curl -fsSL https://repo.ondevice.io/client/version.txt)"
	echo "-- stable version is '$VERSION', downloading and extracting .tgz" >&2
	cd /
	curl -fSL "https://repo.ondevice.io/client/v${VERSION}/ondevice_${VERSION}_${OS}-${ARCH}.tgz" | tar xvz
	if ! [ -x /usr/bin/ondevice ]; then
		echo "ERROR: Couldn't find /usr/bin/ondevice! The installation seems to have failed :(" >&2
		exit 1
	fi

	echo "-- done :)" >&2

	DEVICE_MSG="enable the 'ondevice-daemon' systemd service or init script"
fi

cat >&2 <<EOF

=============================================
Thanks for installing ondevice.
Call 'ondevice login' to set up your account credentials.

To set this computer up as a device, $DEVICE_MSG

Have a look at https://docs.ondevice.io/ for further information.
=============================================

EOF

