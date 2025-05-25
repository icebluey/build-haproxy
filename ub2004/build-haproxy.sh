#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

_private_dir='usr/lib/x86_64-linux-gnu/haproxy/private'

set -e

_strip_files() {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
}

_install_go() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    # Latest version of go
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"

    # go1.24.X
    _go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.24\.' | tail -n 1)"

    wget -q -c -t 0 -T 9 "https://dl.google.com/go/go${_go_version}.linux-amd64.tar.gz"
    rm -fr /usr/local/go
    sleep 1
    install -m 0755 -d /usr/local/go
    tar -xof "go${_go_version}.linux-amd64.tar.gz" --strip-components=1 -C /usr/local/go/
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc --64
    make -j$(nproc --all) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.so*
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
        make -j$(nproc --all) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN' ; export LDFLAGS
        cmake \
        -S "." \
        -B "build" \
        -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
        -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
        -DSYSCONF_INSTALL_DIR:PATH=/etc \
        -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
        -DLIB_SUFFIX=64 \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_zstd() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/facebook/zstd.git"
    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$OOORIGIN' ; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    cd /tmp/zstd
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_pcre2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _pcre2_ver="$(wget -qO- 'https://github.com/PCRE2Project/pcre2/releases' | grep -i 'pcre2-[1-9]' | sed 's|"|\n|g' | grep -i '^/PCRE2Project/pcre2/tree' | sed 's|.*/pcre2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${_pcre2_ver}/pcre2-${_pcre2_ver}.tar.bz2"
    tar -xof pcre2-*.tar.*
    sleep 1
    rm -f pcre2-*.tar*
    cd pcre2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-jit --enable-unicode \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(nproc --all) all
    rm -fr /tmp/pcre2
    make install DESTDIR=/tmp/pcre2
    cd /tmp/pcre2
    rm -fr usr/share/doc/pcre2/html
    _strip_files
    install -m 0755 -d usr/lib/x86_64-linux-gnu/haproxy/private
    cp -af usr/lib/x86_64-linux-gnu/*.so* usr/lib/x86_64-linux-gnu/haproxy/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/pcre2
    /sbin/ldconfig
}

_build_openssl33() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl33_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.3\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.3\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl33_ver}/openssl-${_openssl33_ver}.tar.gz
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 no-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc --all) all
    rm -fr /tmp/openssl33
    make DESTDIR=/tmp/openssl33 install_sw
    cd /tmp/openssl33
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl33
    /sbin/ldconfig
}

_build_aws-lc() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _aws_lc_tag="$(wget -qO- 'https://github.com/aws/aws-lc/tags' | grep -i 'href="/.*/releases/tag/' | sed 's|"|\n|g' | grep -i '/releases/tag/' | sed 's|.*/tag/||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/aws/aws-lc/archive/refs/tags/${_aws_lc_tag}.tar.gz"
    tar -xof *.tar*
    sleep 1
    rm -f *.tar*
    cd aws*
    # Go programming language
    export GOROOT='/usr/local/go'
    export GOPATH="$GOROOT/home"
    export GOTMPDIR='/tmp'
    export GOBIN="$GOROOT/bin"
    export PATH="$GOROOT/bin:$PATH"
    alias go="$GOROOT/bin/go"
    alias gofmt="$GOROOT/bin/gofmt"
    rm -fr ~/.cache/go-build
    echo
    go version
    echo
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN'; export LDFLAGS
    cmake \
    -GNinja \
    -S "." \
    -B "aws-lc-build" \
    -DCMAKE_BUILD_TYPE='Release' \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
    -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
    -DSYSCONF_INSTALL_DIR:PATH=/etc \
    -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
    -DLIB_SUFFIX=64 \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
    cmake --build "aws-lc-build" --parallel $(nproc --all) --verbose
    rm -fr /tmp/aws-lc
    DESTDIR="/tmp/aws-lc" cmake --install "aws-lc-build"
    cd /tmp/aws-lc
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -vf usr/bin/openssl
    rm -vf usr/bin/c_rehash
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -vf /usr/lib/x86_64-linux-gnu/libssl.so
    rm -vf /usr/lib/x86_64-linux-gnu/libcrypto.so
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/aws-lc
    /sbin/ldconfig
}

_build_lua() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _lua_ver="$(wget -qO- 'https://www.lua.org/ftp/' | grep -i '<a href' | sed 's/"/ /g' | sed 's/ /\n/g' | grep -i '^lua-[1-9].*\.tar\.gz$' | sed -e 's|lua-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.lua.org/ftp/lua-${_lua_ver}.tar.gz"
    tar -xof lua-*.tar*
    sleep 1
    rm -f lua-*.tar*
    cd lua-*
    sed 's#INSTALL_TOP=.*#INSTALL_TOP= /usr#g' -i Makefile
    sed 's|INSTALL_LIB=.*|INSTALL_LIB= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed 's|INSTALL_MAN=.*|INSTALL_MAN= /usr/share/man/man1|g' -i Makefile
    make -j$(nproc --all) all
    rm -f /usr/lib/x86_64-linux-gnu/liblua.a
    rm -f /usr/lib/x86_64-linux-gnu/liblua-*
    make install
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    /sbin/ldconfig
}

_build_haproxy() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _haproxy_ver="$(wget -qO- 'https://www.haproxy.org/' | grep -i 'src/haproxy-' | sed 's/"/\n/g' | grep '^/download/' | grep -i '\.gz$' | sed -e 's|.*haproxy-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc[1-9]' | grep '^3\.1' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.haproxy.org/download/${_haproxy_ver%.*}/src/haproxy-${_haproxy_ver}.tar.gz"
    tar -xof haproxy-*.tar*
    sleep 1
    rm -f haproxy-*.tar*
    cd haproxy*
    LDFLAGS=''
    LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    #LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,/usr/lib/x86_64-linux-gnu/haproxy/private'; export LDFLAGS
    sed 's|http://|https://|g' -i include/haproxy/version.h
    sed '/DOCDIR =/s@$(PREFIX)/doc@$(PREFIX)/share/doc@g' -i Makefile
    sed 's#^PREFIX = /usr.*#PREFIX = /usr#g' -i Makefile
    sed 's#^PREFIX = /usr.*#PREFIX = /usr#g' -i admin/systemd/Makefile
    make V=1 -j$(nproc --all) \
    CC='gcc' \
    CXX='g++' \
    CPU=generic \
    TARGET=linux-glibc \
    USE_PCRE2=1 \
    USE_PCRE2_JIT=1 \
    USE_THREAD=1 \
    USE_NS=1 \
    USE_OPENSSL_AWSLC=1 \
    USE_QUIC=1 \
    USE_ZLIB=1 \
    USE_TFO=1 \
    USE_LUA=1 \
    USE_SYSTEMD=1 \
    USE_GETADDRINFO=1 \
    USE_PROMEX=1 \
    ADDLIB="-lz -ldl -pthread" \
    LDFLAGS="${LDFLAGS}"

    #USE_QUIC=1 \
    #EXTRA_OBJS="addons/promex/service-prometheus.o"
    echo
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}" ; export LDFLAGS
    make admin/halog/halog SBINDIR=/usr/bin OPTIMIZE= CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
    for admin in iprange; do
        make -C admin/$admin SBINDIR=/usr/bin OPTIMIZE= CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
    done
    echo
    for admin in systemd; do
        make -C admin/$admin SBINDIR=/usr/sbin
    done
    rm -fr /tmp/haproxy
    make install DESTDIR=/tmp/haproxy
    install -m 0755 -d /tmp/haproxy/usr/bin
    install -m 0755 -d /tmp/haproxy/etc/haproxy/errors
    install -m 0755 -d /tmp/haproxy/etc/sysconfig
    install -m 0755 -d /tmp/haproxy/usr/share/doc/haproxy/examples
    for admin in halog iprange; do
        install -v -s -c -m 0755 -D admin/$admin/$admin /tmp/haproxy/usr/bin/$admin
    done
    install -v -s -c -m 0755 admin/iprange/ip6range /tmp/haproxy/usr/bin/
    install -v -c -m 0644 admin/systemd/haproxy.service /tmp/haproxy/etc/haproxy/
    sed -e '/Environment=/s| "PIDFILE=/.*/haproxy.pid"||g' -e '/ExecStart=/s| -p $PIDFILE||g' -i /tmp/haproxy/etc/haproxy/haproxy.service
    cp -pfr examples /tmp/haproxy/usr/share/doc/haproxy/
    install -c -m 0644 examples/errorfiles/*.http /tmp/haproxy/etc/haproxy/errors/
    cd /tmp/haproxy
    _strip_files
    if [[ -d usr/libexec/haproxy-core ]]; then
        find usr/libexec/haproxy-core/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    rm -f etc/sysconfig/haproxy
    rm -f etc/haproxy/haproxy.cfg
    rm -f etc/haproxy/haproxy.cfg.default

    ############################################################################
    # 
    ############################################################################

    echo '# Add extra options to the haproxy daemon here. This can be useful for
    # specifying multiple configuration files with multiple -f options.
    # See haproxy(1) for a complete list of options.
    OPTIONS=""' >etc/sysconfig/haproxy
    sed 's|^    ||g' -i etc/sysconfig/haproxy
    chmod 0644 etc/sysconfig/haproxy

    ############################################################################
    # 
    ############################################################################

    echo '#---------------------------------------------------------------------
    # Example configuration for a possible web application.  See the
    # full configuration options online.
    #
    #   https://www.haproxy.org/download/3.1/doc/configuration.txt
    #
    #---------------------------------------------------------------------
    
    #---------------------------------------------------------------------
    # Global settings
    #---------------------------------------------------------------------
    global
        log         /dev/log local0
        log         /dev/log local1 notice
        chroot      /var/lib/haproxy
        pidfile     /var/run/haproxy.pid
        maxconn     5000
        user        haproxy
        group       haproxy
        daemon
    
        # turn on stats unix socket
        stats socket /var/lib/haproxy/stats
    
        # utilize system-wide crypto-policies
        ssl-default-bind-ciphers PROFILE=SYSTEM
        ssl-default-server-ciphers PROFILE=SYSTEM
    
    #---------------------------------------------------------------------
    # common defaults that all the '\''listen'\'' and '\''backend'\'' sections will
    # use if not designated in their block
    #---------------------------------------------------------------------
    defaults
        mode                    http
        log                     global
        option                  httplog
        option                  dontlognull
        option http-server-close
        option forwardfor       except 127.0.0.0/8
        option                  redispatch
        retries                 3
        timeout http-request    10s
        timeout queue           1m
        timeout connect         10s
        timeout client          1m
        timeout server          1m
        timeout http-keep-alive 10s
        timeout check           10s
        maxconn                 3000
    
    #---------------------------------------------------------------------
    # main frontend which proxys to the backends
    #---------------------------------------------------------------------
    frontend main
        bind *:5000
        acl url_static       path_beg       -i /static /images /javascript /stylesheets
        acl url_static       path_end       -i .jpg .gif .png .css .js
    
        use_backend static          if url_static
        default_backend             app
    
    #---------------------------------------------------------------------
    # static backend for serving up images, stylesheets and such
    #---------------------------------------------------------------------
    backend static
        balance     roundrobin
        server      static 127.0.0.1:4331 check
    
    #---------------------------------------------------------------------
    # round robin balancing between the various backends
    #---------------------------------------------------------------------
    backend app
        balance     roundrobin
        server  app1 127.0.0.1:5001 check
        server  app2 127.0.0.1:5002 check
        server  app3 127.0.0.1:5003 check
        server  app4 127.0.0.1:5004 check' >etc/haproxy/haproxy.cfg.default
    sed 's|^    ||g' -i etc/haproxy/haproxy.cfg.default
    chmod 0644 etc/haproxy/haproxy.cfg.default

    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    #
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    echo '
    cd "$(dirname "$0")"
    getent group haproxy >/dev/null || groupadd -r haproxy
    getent passwd haproxy >/dev/null || useradd -r -g haproxy \
      -d /var/lib/haproxy -s /usr/sbin/nologin -c "HAProxy Load Balancer" haproxy
    rm -f /lib/systemd/system/haproxy.service
    systemctl daemon-reload >/dev/null 2>&1 || : 
    install -v -c -m 0644 haproxy.service /lib/systemd/system/
    [[ -e /etc/haproxy/haproxy.cfg ]] || (install -v -m 0644 /etc/haproxy/haproxy.cfg.default /etc/haproxy/haproxy.cfg && chown root:root /etc/haproxy/haproxy.cfg)
    [[ -d /etc/rsyslog.d ]] || install -m 0755 -d /etc/rsyslog.d
    [[ -d /etc/logrotate.d ]] || install -m 0755 -d /etc/logrotate.d
    [[ -d /var/lib/haproxy/dev ]] || install -m 0755 -d /var/lib/haproxy/dev
    [[ -d /var/log/haproxy ]] || install -m 0755 -d /var/log/haproxy
    [[ -f /var/log/haproxy/haproxy.log ]] || install -m 0600 /dev/null /var/log/haproxy/haproxy.log
    chown -R haproxy:haproxy /var/lib/haproxy
    chown haproxy:haproxy /var/log/haproxy
    chown syslog:adm /var/log/haproxy/haproxy.log
    systemctl daemon-reload >/dev/null 2>&1 || : 
    echo '\''$AddUnixListenSocket /var/lib/haproxy/dev/log
    :programname, startswith, "haproxy" {
        /var/log/haproxy/haproxy.log
        stop
    }'\'' >/etc/rsyslog.d/10-haproxy.conf
    chmod 0644 /etc/rsyslog.d/10-haproxy.conf
    echo '\''/var/log/haproxy/*log {
        daily
        rotate 30
        dateext
        missingok
        notifempty
        compress
        sharedscripts
        postrotate
            /usr/bin/killall -HUP rsyslogd 2> /dev/null || true
            /usr/bin/killall -HUP syslogd 2> /dev/null || true
        endscript
    }'\'' >/etc/logrotate.d/haproxy
    chmod 0644 /etc/logrotate.d/haproxy
    sleep 1
    systemctl restart rsyslog.service >/dev/null 2>&1 || : 
    systemctl restart logrotate.service >/dev/null 2>&1 || : 
    ' > etc/haproxy/.install.txt
    sed 's|^    ||g' -i etc/haproxy/.install.txt

    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    #
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    install -m 0755 -d usr/lib/x86_64-linux-gnu/haproxy
    cp -afr /usr/lib/x86_64-linux-gnu/haproxy/private usr/lib/x86_64-linux-gnu/haproxy/
    # ubuntu 20.04 patchelf 0.10
    patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu/haproxy/private' usr/sbin/haproxy
    rm -fr var
    rm -fr lib
    echo
    sleep 2
    tar -Jcvf /tmp/haproxy-"${_haproxy_ver}"-1_ub2004_amd64.tar.xz *
    echo
    sleep 2
    cd /tmp
    openssl dgst -r -sha256 haproxy-"${_haproxy_ver}"-1_ub2004_amd64.tar.xz | sed 's|\*| |g' > haproxy-"${_haproxy_ver}"-1_ub2004_amd64.tar.xz.sha256
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/haproxy
    /sbin/ldconfig
}

############################################################################

apt update -y ; apt install -y  patchelf
apt install -y cmake ninja-build clang perl

rm -fr /usr/lib/x86_64-linux-gnu/haproxy

_build_zlib

#_build_brotli
#_build_zstd
#_build_openssl33

_install_go
_build_aws-lc

_build_pcre2
_build_lua
_build_haproxy

echo
echo ' build haproxy ub2004 done'
echo
exit
