# TuxResponse
Linux Incident Response

![image](https://user-images.githubusercontent.com/13645356/64132606-3a363200-cdd1-11e9-83f9-b1d697af2cf0.png)

TuxResponse is a IR script written in bash to automate incident response activities on unprotected Linux systems. Usually corporate systems would have some kind of monitoring and control, but there are exceptions due to shadow IT and non-standard images deployed in corps. 
What amounts to typing of 10 commands with mistakes, can be done in a press of a button.

Tested on:
- Ubuntu 14+
- CentOS 7+

Primary purpose:
- Take advantage of built-in tools and functionality in Linux (tools like dd, awk, grep, cat, netstat, etc)
- Reduce the amount of commands incident responder needs to remember/use in response scenario.
- Automation

External tools in the package: 
- LiME
- Exif
- Chckrootkit
- Yara + Linux scanning rules (needs network to fetch the repo)



Example automation:

#INSTALL LiME
function init_lime(){

  if [ -f /usr/bin/yum ]; then
    yum -y install make kernel-headers kernel-devel gcc
  elif [ -f /usr/bin/apt-get ]; then
    apt-add-repository universe
    apt-get -y install make linux-headers-$(uname -r) gcc
  fi

  rm -f /tmp/v1.8.1.zip
  wget -P/tmp https://github.com/504ensicsLabs/LiME/archive/v1.8.1.zip
  unzip /tmp/v1.8.1.zip
  rm -f /tmp/v1.8.1.zip

  pushd LiME-1.8.1/src
    make
    mv lime-*.ko /tmp/lime.ko
  popd
  rm -rf LiME-1.8.1
}

When responding to incidents, if you have to install LiME by manually typing all the commands, that will slow you down 
significantly.

