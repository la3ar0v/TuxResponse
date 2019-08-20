#!/bin/bash

#Note: chkrootkit builds as static by default

function chkrootkit_compile(){
  wget -P/tmp ftp://ftp.pangeia.com.br/pub/seg/pac/chkrootkit.tar.gz
  tar -xf /tmp/chkrootkit.tar.gz
  rm -f /tmp/chkrootkit.tar.gz

  CHK_VER=$(ls -d chkrootkit-* | cut -f2 -d'-')

  pushd chkrootkit-${CHK_VER}
    make sense
    tar -czf ../chkrootkit-${CHK_VER}.tar.gz chklastlog chkutmp chkproc ifpromisc chkwtmp check_wtmpx strings-static chkdirs chkrootkit
  popd
}
