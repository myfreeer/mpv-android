#!/bin/bash -e

. ./include/depinfo.sh

. ./include/path.sh # load $os var

[ -z "$TRAVIS" ] && TRAVIS=0 # skip steps not required for CI?
[ -z "$WGET" ] && WGET=wget # possibility of calling wget differently 

if [ "$os" == "linux" ]; then
	hash yum &> /dev/null && sudo yum install zlib.i686 ncurses-libs.i686 bzip2-libs.i686 \
		autoconf m4 pkgconfig libtool
	apt-get -v &> /dev/null && [ $TRAVIS -eq 0 ] && \
		sudo apt-get install lib32z1 lib32ncurses5 lib32stdc++6 autoconf m4 pkg-config libtool

	os_ndk="linux"
elif [ "$os" == "macosx" ]; then
	if ! hash brew 2>/dev/null; then
		echo "Error: brew not found. You need to install Homebrew: https://brew.sh/"
		exit 255
	fi
	brew install \
		automake autoconf libtool pkg-config \
		coreutils gnu-sed wget
	if ! java -version &>/dev/null; then
		echo "Error: missing Java 8 runtime. Manually install it or use:"
		echo "\$ brew tap caskroom/versions"
		echo "\$ brew cask install java8"
		exit 255
	fi

	os_ndk="darwin"
fi

mkdir -p sdk && cd sdk

# android-sdk-$os
if [ $TRAVIS -eq 0 ]; then
	$WGET "https://dl.google.com/android/repository/sdk-tools-${os_ndk}-${v_sdk}.zip"
	mkdir "android-sdk-${os}"
	unzip -q -d "android-sdk-${os}" "sdk-tools-${os_ndk}-${v_sdk}.zip"
	rm "sdk-tools-${os_ndk}-${v_sdk}.zip"
	"./android-sdk-${os}/tools/bin/sdkmanager" \
		"platforms;android-27" "build-tools;27.0.3" "extras;android;m2repository" "platform-tools"
fi

# android-ndk-$v_ndk
$WGET "http://dl.google.com/android/repository/android-ndk-${v_ndk}-${os_ndk}-x86_64.zip"
unzip -q "android-ndk-${v_ndk}-${os_ndk}-x86_64.zip"
rm "android-ndk-${v_ndk}-${os_ndk}-x86_64.zip"

# ndk-toolchain
cd "android-ndk-${v_ndk}"
toolchain_api=21
./build/tools/make_standalone_toolchain.py \
	--arch arm64 --api $toolchain_api \
	--install-dir `pwd`/../ndk-toolchain-arm64
if [ $TRAVIS -eq 0 ]; then
	./build/tools/make_standalone_toolchain.py \
		--arch arm --api $toolchain_api \
		--install-dir `pwd`/../ndk-toolchain
	./build/tools/make_standalone_toolchain.py \
		--arch x86_64 --api $toolchain_api \
		--install-dir `pwd`/../ndk-toolchain-x64
	./build/tools/make_standalone_toolchain.py \
		--arch x86 --api $toolchain_api \
		--install-dir `pwd`/../ndk-toolchain-x86
fi
for tc in ndk-toolchain{,-arm64,-x64,-x86}; do
	[ ! -d ../$tc ] && continue
	pushd ../$tc

	rm -rf bin/py* lib/{lib,}py* # remove python because it can cause breakage
	# add gas-preprocessor.pl for ffmpeg + clang on ARM
	$WGET "https://git.libav.org/?p=gas-preprocessor.git;a=blob_plain;f=gas-preprocessor.pl;hb=HEAD" \
		-O bin/gas-preprocessor.pl
	chmod +x bin/gas-preprocessor.pl
	# make wrapper to pass api level to gcc (due to Unified Headers)
	exe=`echo bin/*-linux-android*-gcc`
	mv $exe{,.real}
	printf '#!/bin/sh\nexec $0.real -D__ANDROID_API__=%s "$@"\n' $toolchain_api >$exe
	chmod +x $exe

	popd
done
cd ..

cd ..
