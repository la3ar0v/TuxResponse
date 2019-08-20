#!/bin/bash -e

function jansson_compile(){
  wget -P/tmp http://www.digip.org/jansson/releases/jansson-latest.tar.gz
  tar -xf /tmp/jansson-latest.tar.gz
  rm -f /tmp/jansson-latest.tar.gz

  pushd jansson-2.*
    CFLAGS='-static' ./configure --disable-shared --enable-static
    make && make install
  popd
}

function libmagic_compile(){
  wget -P/tmp/ ftp://ftp.astron.com/pub/file/file-5.36.tar.gz
  tar -xf /tmp/file-5.36.tar.gz
  rm -f /tmp/file-5.36.tar.gz

  pushd file-5.*
    CFLAGS='-static' ./configure --disable-shared --enable-static
    make && make install
  popd
}

function yara_compile(){

  #install dependancies
  if [ -f /usr/bin/yum ]; then
    yum -y install autoconf flex byacc openssl-devel libtool
    yum -y install glibc-static file-static openssl-static zlib-static
  elif [ -f /usr/bin/apt-get ]; then
    apt-get install -y autoconf flex byacc libssl-dev libtool libbsd-dev
  fi

  #get latest version
  wget -P/tmp/ https://github.com/VirusTotal/yara/releases/latest
  YARA_VER=$(sed -n 's/.*<title>Release YARA \([0-9\.]\+\).*/\1/p' /tmp/latest)
  rm -f /tmp/latest


  #download source file
  wget -P/tmp https://github.com/VirusTotal/yara/archive/v${YARA_VER}.tar.gz
  tar -xzf /tmp/v${YARA_VER}.tar.gz
  rm -f /tmp/v${YARA_VER}.tar.gz

  #compile
  # ldd .libs/yara
	#linux-vdso.so.1 =>  (0x00007ffca3b1a000)
	#libyara.so.3 => not found
	#libcrypto.so.10 => /usr/lib64/libcrypto.so.10 (0x00007f623acb3000)
	#libmagic.so.1 => /usr/lib64/libmagic.so.1 (0x00007f623aa94000)
	#libjansson.so.4 => /usr/lib64/libjansson.so.4 (0x00007f623a887000)
	#libm.so.6 => /lib64/libm.so.6 (0x00007f623a602000)
	#libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f623a3e5000)
	#libc.so.6 => /lib64/libc.so.6 (0x00007f623a051000)
	#libdl.so.2 => /lib64/libdl.so.2 (0x00007f6239e4c000)
	#libz.so.1 => /lib64/libz.so.1 (0x00000031bf600000)
	#/lib64/ld-linux-x86-64.so.2 (0x0000561bb0109000)

  pushd yara-${YARA_VER}
    ./bootstrap.sh

    #working
    if [ -f /usr/bin/apt-get ]; then
      export LIBS='-L/usr/local/lib/ -L/usr/lib/x86_64-linux-gnu/ -Wl,-Bstatic -lcrypto -lmagic -ljansson -lbsd -Wl,-Bdynamic -ldl -lz -lc -lpthread -lm'
    else
      export LIBS='-L/usr/local/lib/ -Wl,-Bstatic -lcrypto -lmagic -ljansson -Wl,-Bdynamic -ldl -lz -lc -lpthread -lm'
    fi
    ./configure --prefix=/usr/local --disable-shared --enable-static --enable-cuckoo --enable-magic --enable-dotnet

    make
    make install
  popd
}

if [ -f /usr/bin/yum ]; then
  yum -y install wget unzip gcc glibc-static automake
elif [ -f /usr/bin/apt-get ]; then
  apt-get install -y wget unzip gcc libc6-dev automake texinfo make
fi

jansson_compile;
libmagic_compile;
yara_compile;
