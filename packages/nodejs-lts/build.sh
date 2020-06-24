TERMUX_PKG_HOMEPAGE=https://nodejs.org/
TERMUX_PKG_DESCRIPTION="Platform built on Chrome's JavaScript runtime for easily building fast, scalable network applications"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_VERSION=12.16.3
TERMUX_PKG_SRCURL=https://nodejs.org/dist/v${TERMUX_PKG_VERSION}/node-v${TERMUX_PKG_VERSION}.tar.xz
TERMUX_PKG_SHA256=f0559b0829c7f2ac10bf5b3e157e498227e95e26cdb6af814969c49f367359a3
# Note that we do not use a shared libuv to avoid an issue with the Android
# linker, which does not use symbols of linked shared libraries when resolving
# symbols on dlopen(). See https://github.com/termux/termux-packages/issues/462.
TERMUX_PKG_DEPENDS="libc++, openssl, c-ares, libicu, zlib"
TERMUX_PKG_CONFLICTS="nodejs, nodejs-current"
TERMUX_PKG_BREAKS="nodejs-dev"
TERMUX_PKG_REPLACES="nodejs-current, nodejs-dev"
TERMUX_PKG_SUGGESTS="clang, make, pkg-config, python"
TERMUX_PKG_RM_AFTER_INSTALL="lib/node_modules/npm/html lib/node_modules/npm/make.bat share/systemtap lib/dtrace"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_HOSTBUILD=true

termux_step_post_extract_package() {
	# Prevent caching of host build:
	rm -Rf $TERMUX_PKG_HOSTBUILD_DIR
}

termux_step_host_build() {
	local ICU_VERSION=66.1
	local ICU_TAR=icu4c-${ICU_VERSION//./_}-src.tgz
	local ICU_DOWNLOAD=https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/$ICU_TAR
	termux_download \
		$ICU_DOWNLOAD\
		$TERMUX_PKG_CACHEDIR/$ICU_TAR \
		52a3f2209ab95559c1cf0a14f24338001f389615bf00e2585ef3dbc43ecf0a2e
	tar xf $TERMUX_PKG_CACHEDIR/$ICU_TAR
	cd icu/source
	if [ "$TERMUX_ARCH_BITS" = 32 ]; then
		./configure --prefix $TERMUX_PKG_HOSTBUILD_DIR/icu-installed \
			--disable-samples \
			--disable-tests \
			--build=i686-pc-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32"
	else
		./configure --prefix $TERMUX_PKG_HOSTBUILD_DIR/icu-installed \
			--disable-samples \
			--disable-tests
	fi
	make -j $TERMUX_MAKE_PROCESSES install
}

termux_step_configure() {
	local DEST_CPU
	if [ $TERMUX_ARCH = "arm" ]; then
		DEST_CPU="arm"
	elif [ $TERMUX_ARCH = "i686" ]; then
		DEST_CPU="ia32"
	elif [ $TERMUX_ARCH = "aarch64" ]; then
		DEST_CPU="arm64"
	elif [ $TERMUX_ARCH = "x86_64" ]; then
		DEST_CPU="x64"
	else
		termux_error_exit "Unsupported arch '$TERMUX_ARCH'"
	fi

	export GYP_DEFINES="host_os=linux"
	export CC_host=gcc
	export CXX_host=g++
	export LINK_host=g++

	# See note above TERMUX_PKG_DEPENDS why we do not use a shared libuv.
	./configure \
		--prefix=$TERMUX_PREFIX \
		--dest-cpu=$DEST_CPU \
		--dest-os=android \
		--shared-cares \
		--shared-openssl \
		--shared-zlib \
		--with-intl=system-icu \
		--without-snapshot \
		--without-node-snapshot \
		--cross-compiling

	export LD_LIBRARY_PATH=$TERMUX_PKG_HOSTBUILD_DIR/icu-installed/lib
	perl -p -i -e "s@LIBS := \\$\\(LIBS\\)@LIBS := -L$TERMUX_PKG_HOSTBUILD_DIR/icu-installed/lib -lpthread -licui18n -licuuc -licudata@" \
		$TERMUX_PKG_SRCDIR/out/tools/v8_gypfiles/torque.host.mk \
		$TERMUX_PKG_SRCDIR/out/tools/v8_gypfiles/bytecode_builtins_list_generator.host.mk \
		$TERMUX_PKG_SRCDIR/out/tools/v8_gypfiles/v8_libbase.host.mk \
		$TERMUX_PKG_SRCDIR/out/tools/v8_gypfiles/gen-regexp-special-case.host.mk
}