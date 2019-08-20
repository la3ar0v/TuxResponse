function exiftool_install(){
  #get version
  wget -P/tmp https://www.sno.phy.queensu.ca/~phil/exiftool/
  EXIF_VER=$(sed -n 's/.*Download[ \t]\+Version \([0-9\.]\+\).*/\1/p' /tmp/index.html)
  rm -f /tmp/index.html

  #download source
  wget -P/tmp https://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-${EXIF_VER}.tar.gz
  tar -xf /tmp/Image-ExifTool-${EXIF_VER}.tar.gz
  rm -f /tmp/Image-ExifTool-${EXIF_VER}.tar.gz

  #compile
  pushd Image-ExifTool-${EXIF_VER}
    perl Makefile.PL
    make test
    make install

    #to make the tgz
    make uninstall | grep unlink | cut -f2 -d' ' >/tmp/exif.list
  popd
  rm -f Image-ExifTool-${EXIF_VER}

  #to make the tgz
  tar -czf ../exiftool-${EXIF_VER}-1.ubuntu18.tgz -T/tmp/exif.list
  rm -f /tmp/exif.list
}

if [ -f /usr/bin/yum ]; then
  yum -y install make perl wget
elif [ -f /usr/bin/apt-get ]; then
  apt-get -y install make perl wget
fi

exiftool_install;
