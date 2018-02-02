#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

. ./include/depinfo.sh

build_prefix() {
	echo "==> Building the prefix ($travis_tarball)..."

	echo "==> Fetching deps"
	TRAVIS=1 ./include/download-deps.sh

	# build everything mpv depends on (but not mpv itself)
	for x in ${dep_mpv[@]}; do
		echo "==> Building $x"
		./buildall.sh $x
	done
}

export WGET="wget --progress=bar:force"

if [ "$1" == "install" ]; then
	echo "==> Fetching NDK"
	TRAVIS=1 ./include/download-sdk.sh
	# link global SDK into our dir structure
	ln -s /usr/local/android-sdk ./sdk/android-sdk-linux

	echo "==> Fetching mpv"
	mkdir -p deps/mpv
	$WGET https://github.com/mpv-player/mpv/archive/master.tar.gz -O master.tgz
	tar -xzf master.tgz -C deps/mpv --strip-components=1 && rm master.tgz

	echo "==> Building prefix"
	build_prefix
	exit 0
elif [ "$1" == "build" ]; then
	:
else
	exit 1
fi

echo "==> Building mpv"
./buildall.sh --no-deps mpv || {
	# show logfile if configure failed
	[ ! -f deps/mpv/_build/config.h ] && cat deps/mpv/_build/config.log
	exit 1
}

echo "==> Building mpv-android"
./buildall.sh --no-deps

echo "==> Uploading the .apk"
curl -F'file=@../app/build/outputs/apk/debug/app-debug.apk' http://0x0.st

exit 0
