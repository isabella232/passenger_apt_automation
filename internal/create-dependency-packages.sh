#!/bin/bash
set -e

BASE_DIR=`dirname "$0"`
BASE_DIR=`cd "$BASE_DIR/.." && pwd`
source lib/bashlib
load_general_config

function cleanup()
{
	if [[ "$PKG_DIR" != "" ]]; then
		rm -rf "$PKG_DIR"
	fi
}


header "Preparing build directory"
export PKG_DIR=`mktemp -d /tmp/passenger_apt_build.XXXXXXX`
rm -rf $PKG_DIR
mkdir -p $PKG_DIR

header "Clearing previous build results"
run rm -rf ~/pbuilder/*_result/*

header "Cloning repositories"
rm -rf /var/cache/passenger_apt_automation/misc_packages
mkdir -p /var/cache/passenger_apt_automation/misc_packages

if $build_daemon_controller; then
	header "Building daemon_controller"
	git clone git://github.com/FooBarWidget/daemon_controller.git /var/cache/passenger_apt_automation/misc_packages/daemon_controller
	pushd /var/cache/passenger_apt_automation/misc_packages/daemon_controller >/dev/null
	echo "In /var/cache/passenger_apt_automation/misc_packages/daemon_controller:"
	run rake debian:source_packages
	for DIST in $DEBIAN_DISTROS; do
		run pbuilder-dist $DIST i386 build $PKG_DIR/ruby-daemon-controller_*$DIST*.dsc
	done
	popd >/dev/null
fi

if $build_crash_watch; then
	header "Building crash-watch"
	git clone git://github.com/FooBarWidget/crash-watch.git /var/cache/passenger_apt_automation/misc_packages/crash-watch
	pushd /var/cache/passenger_apt_automation/misc_packages/crash-watch >/dev/null
	echo "In /var/cache/passenger_apt_automation/misc_packages/crash-watch:"
	run rake debian:source_packages
	for DIST in $DEBIAN_DISTROS; do
		run pbuilder-dist $DIST i386 build $PKG_DIR/crash-watch_*$DIST*.dsc
	done
	popd >/dev/null
fi

header "Signing packages"
debsign -k$SIGNING_KEY $PKG_DIR/*.changes

header "Importing built packages into APT repositories"

for PROJECT_NAME in passenger passenger-enterprise; do
	RELEASE_DIR=`bash "$BASE_DIR/internal/new_apt_repo_release.sh" "$PROJECT_NAME" "$PROJECT_APT_REPO_DIR"`
	pushd "$RELEASE_DIR" >/dev/null

	for DIST in $DEBIAN_DISTROS; do
		reprepro --keepunusednewfiles -Vb . includedeb $DIST $HOME/pbuilder/$DIST-i386_result/*.deb
		for F in $HOME/pbuilder/$DIST-i386_result/*.dsc; do
			reprepro --keepunusednewfiles -Vb . includedsc $DIST $F
		done
	done

	bash "$BASE_DIR/internal/commit_apt_repo_release.sh" "$RELEASE_DIR"
	popd >/dev/null
done
