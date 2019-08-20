#!/bin/bash

function yara_dynamic(){
  if [ -f /usr/bin/yum ]; then
    #check latest version
    wget -P/tmp/ https://github.com/VirusTotal/yara/releases/latest
    YARA_VER=$(sed -n 's/.*<title>Release YARA \([0-9\.]\+\).*/\1/p' /tmp/latest)
    rm -f /tmp/latest

    #download source file
    wget -P/tmp https://github.com/VirusTotal/yara/archive/v${YARA_VER}.tar.gz
    tar -xzf /tmp/v${YARA_VER}.tar.gz
    rm -f /tmp/v${YARA_VER}.tar.gz

    #needed for compilation
    yum -y install autoconf automake flex byacc jansson jansson-devel file-devel file-libs openssl-devel libtool

    #compile
    pushd yara-${YARA_VER}
      ./bootstrap.sh
      ./configure --prefix=/usr --enable-cuckoo --enable-magic --enable-dotnet
      make
      make install
    popd
    rm -rf yara-${YARA_VER}

  elif [ -f /usr/bin/apt ]; then
    apt-get -y install yara
  fi

  #download YARA rules
  pushd /root
    wget -P/tmp https://github.com/Yara-Rules/rules/archive/master.zip
    unzip /tmp/master.zip
    mv rules-master rules-yara
    rm -f /tmp/master.zip
  popd
}

yara_dynamic
