#!/bin/bash


function lime_compile(){
  wget -P/tmp https://github.com/504ensicsLabs/LiME/archive/master.zip
  unzip /tmp/master.zip
  rm -f /tmp/master.zip

  pushd LiME-master
    make
    mv lime-*.ko lime.ko
  popd

}


if [ -f /usr/bin/yum ]; then
  yum -y install make kernel-devel gcc
elif [ -f /usr/bin/apt-get ]; then
  apt-get -y install linux-headers-generic gcc
fi

lime_compile;
