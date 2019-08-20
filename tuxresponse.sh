#!/bin/bash -e
# Copyright Hristiyan Lazarov

EVIDENCE_DIR='evidence'

#details for remote target
REMOTE_HOME='/opt/TuxResponse'
TARGET_PORT=22
TARGET_HOST=''
TARGET_USER='root'
TARGET_KEY='target.pub'

#port used by LiME to dump remote system memory
MEM_DUMP_PORT=22000


#SSH connection to remote host #

function _enter_target_details(){
  echo "Enter details for your target. Key can be empty."
  read -p "Host: " TARGET_HOST
  read -p "Port: " TARGET_PORT
  read -p "User: " TARGET_USER
  read -p "SSH keyfile (ex. target.pub): " TARGET_KEY

  if [ -z "${TARGET_KEY}" ]; then
    TARGET_KEY='target'
  fi

  if [ ! -f "${TARGET_KEY}" ]; then
    ssh-keygen -f ${TARGET_KEY}
  fi
  ssh-add ./${TARGET_KEY}

  echo "Adding ${TARGET_KEY} to local key agent..."
  ssh-copy-id -f -i ${TARGET_KEY}.pub -p ${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST}
  if [ $? -ne 0 ]; then
    echo "Error: Failed to copy key on target. Remote mode disabled"
    TARGET_HOST=''; #if target host is set, script runs in remote mode!
    return;
  fi

  #copy script on remote system
  echo "Copying TuxResponse to remote system ${REMOTE_HOME} ..."
  ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "mkdir -p ${REMOTE_HOME}"
  scp -P${TARGET_PORT} forensics.sh .menu_en.sh .cmds.sh ${TARGET_USER}@${TARGET_HOST}:${REMOTE_HOME}
  if [ $? -ne 0 ]; then
    echo "Error: Failed to copy key on target. Remote mode disabled"
    TARGET_HOST=''; #if target host is set, script runs in remote mode!
    return;
  fi

  #TODO: if successful, go back to main menu ?
}

#cleanup remote system

function _target_cleanup(){
  ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "rm -r ${REMOTE_HOME}"
  TARGET_HOST=''
}

function _create_disk_image(){

  if [ "${TARGET_HOST}" ]; then
    DISK_DRIVES=$(ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "fdisk -l | sed -n 's/^Disk \(\/dev\/[a-z0-9]\+\): \([0-9.,]\+\) \([MG]iB\).*/\1;\2;\3/p' | sort | uniq")
    DISK_PART=$(ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "fdisk -l | grep '^/dev/' | sed 's/[ \t\*]\+/ /g' | cut -f1,5 -d' ' | sed 's/ /;/'")
  else
    DISK_DRIVES=$(fdisk -l | sed -n 's/^Disk \(\/dev\/[a-z0-9]\+\): \([0-9.,]\+\) \([MG]iB\).*/\1;\2;\3/p' | sort | uniq)
    DISK_PART="$(fdisk -l | grep '^/dev/' | sed 's/[ \t\*]\+/ /g' | cut -f1,5 -d' ' | sed 's/ /;/')"
  fi

  DISK_OPT="$(echo -e "${DISK_DRIVES}\n${DISK_PART}")"
  OPT_COUNT=$(echo "${DISK_OPT}" | wc -w)

  PS3="Please select disk to copy [1-${OPT_COUNT}]: "
  select opt in ${DISK_OPT}; do

    for ((i = 0; i < ${OPT_COUNT}; i++)); do
      if [ "${REPLY}" == "${i}" ]; then
        IMAGE_DISK_INFO="$(echo "${DISK_OPT}" | sed -n ${REPLY}p)"
        break;  #stop the loop
      fi
    done

    if [ -z "${IMAGE_DISK_INFO}" ]; then
      echo "invalid option ${REPLY}"
    else
      break;  #stop select
    fi
  done

  IMAGE_IN="${IMAGE_DISK_INFO%%;*}"
  IMAGE_IN_NAME="${IMAGE_IN##*/}"

  if [ "${TARGET_HOST}" ]; then
    IMAGE_IN_SIZE=$(ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "blockdev --getsz ${IMAGE_IN}")
  else
    IMAGE_IN_SIZE=$(blockdev --getsz ${IMAGE_IN})
  fi

  echo "Listing available storage locations. Select one with at lest ${IMAGE_IN_SIZE} bytes"
  df -h;  #show available storage
  read -p "Enter image storage path: " IMAGE_STORAGE

  IMAGE_OUT="${IMAGE_STORAGE}/${IMAGE_IN_NAME}.dd"

  # Check if we have size in storage
  STORAGE_SIZE_AVAIL=$(df -k "${IMAGE_STORAGE}" | tail -n 1 | sed 's/[ \t]\+/ /g' | cut -f4 -d' ')
  if [ ${STORAGE_SIZE_AVAIL} -lt ${IMAGE_IN_SIZE} ]; then
    echo "Error: Storage size has only ${STORAGE_SIZE_AVAIL} bytes, ${IMAGE_IN_SIZE} needed!"
    return;
  fi

  #if output file exists
  if [ -f "${IMAGE_OUT}" ]; then
    #ask user if we have to delete it
    read -p "${IMAGE_OUT} exists. Overwrite [y/n]"
    if [ "${REPLY}" == 'y' ]; then
      rm -f "${IMAGE_OUT}"
    else
      return; #abort the operation
    fi
  fi

  #creating disk image
  if [ "${TARGET_HOST}" ]; then
    DD_CMD="ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} 'dd if=${IMAGE_IN} bs=8M conv=noerror,sync' | pv | dd of='${IMAGE_OUT}'"
  else
    DD_CMD="dd if=${IMAGE_IN} | pv | dd of='${IMAGE_OUT}' bs=8M conv=noerror,sync"
  fi

  echo "DD_CMD=${DD_CMD}"
  read -p 'Confirm clone command [y/n]: '
  if [ "${REPLY}" == 'y' ]; then
    eval ${DD_CMD}
  fi
}

#memory dump function

function _create_mem_image(){
  if [ "${TARGET_HOST}" ]; then
    MEM_SIZE=$(ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "free | sed 's/[ \t]\+/ /g' | grep -i 'Mem:' | cut -f2 -d' '")
  else
    MEM_SIZE=$(free | sed 's/[ \t]\+/ /g' | grep -i 'Mem:' | cut -f2 -d' ')
  fi

  echo "Listing available storage locations. Select one with at lest ${IMAGE_IN_SIZE} bytes"
  df -h;  #show available storage
  read -p "Enter image storage path: " IMAGE_STORAGE
  read -p "Enter image name [ default is DATETIME.lime]: " IMAGE_IN_NAME

  if [ -z "${IMAGE_IN_NAME}" ]; then
    IMAGE_IN_NAME=$(date '+%d%m%Y_%T')
  fi
  IMAGE_OUT="${IMAGE_STORAGE}/${IMAGE_IN_NAME}.lime"

  # Check if we have size in storage
  STORAGE_SIZE_AVAIL=$(df -k "${IMAGE_STORAGE}" | tail -n 1 | sed 's/[ \t]\+/ /g' | cut -f4 -d' ')
  if [ ${STORAGE_SIZE_AVAIL} -lt ${MEM_SIZE} ]; then
    echo "Error: Storage size has only ${STORAGE_SIZE_AVAIL} bytes, ${MEM_SIZE} needed!"
    return;
  fi

  #if output filex exists
  if [ -f "${IMAGE_OUT}" ]; then
    #ask user if we have to delete it
    read -p "${IMAGE_OUT} exists. Overwrite [y/n]"
    if [ "${REPLY}" == 'y' ]; then
      rm -f "${IMAGE_OUT}"
    else
      return; #abort the operation
    fi
  fi

  #create memory image
  echo "Inserting LiME module ..."
  if [ "${TARGET_HOST}" ]; then
    ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "insmod /tmp/lime.ko 'path=tcp:${MEM_DUMP_PORT} format=lime'" &
    sleep 5;
    nc ${TARGET_HOST} ${MEM_DUMP_PORT} </dev/null | pv > ${IMAGE_OUT}

    ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "rmmod lime"

  else
    insmod /tmp/lime.ko "path=tcp:${MEM_DUMP_PORT} format=lime" &
    sleep 5;
    nc localhost ${MEM_DUMP_PORT} </dev/null | pv > ${IMAGE_OUT}

    rmmod lime
  fi
}

#install LiME
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

function modified_files_period_select(){
  local timestamp='/tmp/.find_timestamp'
  local period=("minute" "hour" "day" "week" "month" "Back")
  PS3="Please enter your choice[1-${#period[@]}]: "

  select opt in "${period[@]}"
  do
    case $REPLY in
        [1-5])
          break ;;
        6)
          return;
          break;;
        *) echo "invalid option $REPLY";;
    esac
  done

  touch -d "1 $opt ago" ${timestamp}
  find / -type f -newer ${timestamp}
}

function packaged_files_changed(){
  if [ "$(which rpm || true)" ]; then
    rpm -Va | grep ^..5.
  elif [ "$(which debsums || true)" ]; then
    debsums -c
  else
    echo "Error: No package manager found!"
  fi
}

function yara_select(){
  echo "YARA:$(which yara)"
  echo "Rules: /usr/local/share/rules-yara"
  echo "Starting shell, press Ctrl-D or type exit to return to menu."
  bash
}

function exiftool_select(){
  echo "exiftool:$(which exiftool)"
  echo "Starting shell, press Ctrl-D or type exit to return to menu."
  bash
}

function list_all_crontab(){
  for user in $(getent passwd | cut -f1 -d:); do
    echo $user;
    crontab -u $user -l;
  done

  #well known cron directories in /etc
  for subdir in d hourly daily monthly deny; do
    if [ -d "/etc/cron.${subdir}" ]; then
      find /etc/cron.${subdir} -type f | xargs more
    fi
  done

  if [ -f /etc/crontab ]; then
    cat <<CMD_EOF
::::::::::::::
/etc/crontab
::::::::::::::
CMD_EOF
    cat /etc/crontab
  fi

  if [ "$(which atq || true)" ]; then
    cat <<CMD_EOF
::::::::::::::
atq
::::::::::::::
CMD_EOF
    atq
  fi

  if [ "$(which systemctl || true)" ]; then
    cat <<CMD_EOF
::::::::::::::
systemctl list-timers
::::::::::::::
CMD_EOF
    systemctl list-timers --all
  fi

}

function list_all_onstartup(){
  #show scripts for each runlevel
  for d in rc1.d rc2.d rc3.d rc5.d rc6.d rc.d init.d; do
    if [ -d "/etc/${d}" ]; then
      echo "/etc/${d}"
      ls -l "/etc/${d}"
    fi
  done

  if [ "$(which systemctl || true)" ]; then
    systemctl list-unit-files | grep enabled
  fi

  if [ "$(which chkconfig || true)" ]; then
    chkconfig
  fi

  if [ -f /etc/rc.local ]; then
    echo "/etc/rc.local is present. Content is below."
    cat -n /etc/rc.local
  fi

  echo "CRON @reboot ->"
  find /etc/cron.* -type f -exec grep -H '@reboot' {} \;
  grep -H '@reboot' /etc/crontab
}

function cat_all_bash_history(){

  cat <<CMD_EOF
::::::::::::::
/root/.bash_history
::::::::::::::
CMD_EOF
  cat -n /root/.bash_history

  for user in $(getent passwd | cut -f1 -d: | grep -v root); do
    cat <<CMD_EOF
::::::::::::::
/${user}/.bash_history
::::::::::::::
CMD_EOF
    if [ -f "/home/$user/.bash_history" ]; then
      cat -n /home/$user/.bash_history
    else
      echo 'empty'
    fi
  done
}

function dump_process_select(){
  read -p "Enter process PID: " DUMP_PID
  read -p "Enter output file: " DUMP_FILE

  gcore -a -o "${DUMP_FILE}" ${DUMP_PID}
}

function _init_exiftool(){
  if [ "${TARGET_HOST}" ]; then
    SAVED_SEL="${SELECTION}"
    CMD='true'
    SELECTION='0,2,3' #show distro version
    PKG_DISTRO_VER=$(exec_CMD)
    SELECTION="${SAVED_SEL}"
  else
    PKG_DISTRO_VER=$(show_distro_ver)
  fi

  local filename=""
  case ${PKG_DISTRO_VER} in
    centos*)
      filename='exiftool-11.37-1.centos.tgz'
      ;;
    ubuntu*)
      filename='exiftool-11.38-1.ubuntu-18.tgz'
      ;;
    *)
      echo "Error: No EXIF package for ${PKG_DISTRO_VER}";;
  esac

  if [ "${TARGET_HOST}" ]; then
    scp -P${TARGET_PORT} dist/${filename} ${TARGET_USER}@${TARGET_HOST}:/tmp/
    ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "tar -C/ -xf /tmp/${filename}; rm -f /tmp/${filename}"
  else
    tar -C/ -xf dist/${filename}
  fi
}

function _init_chkrootkit(){
  local filename='chkrootkit-0.53.ubuntu-18.tar.gz'

  if [ "${TARGET_HOST}" ]; then
    scp -P${TARGET_PORT} dist/${filename} ${TARGET_USER}@${TARGET_HOST}:/tmp/
    ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "tar -C/usr/local/bin/ -xf /tmp/${filename}; rm -f /tmp/${filename}; ln -s /usr/local/bin/strings-static /usr/local/bin/strings"
  else
    pushd /usr/local/bin/
    tar -xf dist/${filename}
    ln -s /usr/local/bin/strings-static /usr/local/bin/strings
    popd
  fi
}

function _init_yara(){

  #download YARA rules
  pushd /tmp/
  wget https://github.com/Yara-Rules/rules/archive/master.zip
  unzip master.zip
  rm -f master.zip
  mv rules-master rules-yara
  popd

  if [ "${TARGET_HOST}" ]; then
    SAVED_SEL="${SELECTION}"
    CMD='true'
    SELECTION='0,2,3' #show distro version
    PKG_DISTRO_VER=$(exec_CMD)
    SELECTION="${SAVED_SEL}"
  else
    PKG_DISTRO_VER=$(show_distro_ver)
  fi

  local filename="yara-static-3.9.0-1.${PKG_DISTRO_VER}.x86_64.tgz"

  if [ "${TARGET_HOST}" ]; then
    scp -P${TARGET_PORT} dist/${filename} ${TARGET_USER}@${TARGET_HOST}:/tmp/
    ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "tar -C/ -xf /tmp/${filename}; rm -f /tmp/${filename}"
    scp -P${TARGET_PORT} -r /tmp/rules-yara ${TARGET_USER}@${TARGET_HOST}:/usr/local/share/
  else

    rm -rf /usr/local/share/rules-yara
    mv /tmp/rules-yara /usr/local/share/

    tar -C/ -xf dist/${filename}
  fi
}

function show_distro_ver(){
  echo "${DISTRO}-${DISTRO_VER}"
}

function init_deps(){

  #install various packages needed for menus to work
  if [ "${DISTRO}" == 'centos' ]; then
    yum -y install wget unzip gdb pv
  elif [ "${DISTRO}" == 'ubuntu' ]; then

    if [ "${DISTRO_VER}" == '18' ]; then
      apt-add-repository universe
    fi
    apt-get -y install wget unzip gdb debsums pv netstat
  fi
}

function init_check_binaries(){
  local -n arr=$1
  len=${#arr[@]}
  for i in $(seq 0 $((len-1))); do
    for prog in $(echo "${arr[$i]}" | sed 's/\([^\\]\)[;\|][ \t]\+/\1\n/g' | cut -f1 -d' '); do
      bin_name=$(echo ${prog} | cut -f1 -d' ')

      #skip names of internal functions
      if [ "$(type -t ${bin_name})" == "function" ]; then
        continue;
      fi

      bin_path=$(which ${bin_name} 2>/dev/null || true)
      if [ "${bin_path}" ]; then
        echo "OKAY ${bin_name}"
      else
        echo "FAIL ${bin_name}"
      fi
    done
  done
}

function init_check(){
  init_check_binaries cmds6
  init_check_binaries cmds11
  init_check_binaries cmds12
  init_check_binaries cmds13
  init_check_binaries cmds14
  init_check_binaries cmds15
  init_check_binaries cmds16
  init_check_binaries cmds17
  init_check_binaries cmds18
  init_check_binaries cmds19

  init_check_binaries cmd_deps
}

function show_menu_header(){
  HOST_AT='@localhost'
  if [ "${TARGET_HOST}" ]; then
    HOST_AT="@${TARGET_HOST}"
  fi

  prev=0
  for mid in $(echo "${1}" | tr ',' ' '); do
    if [ "$mid" == '0' ]; then
      echo -n "# ${HOST_AT} # Home/"
    else
      let aid=mid-1 || true
      local tmp="menu${prev}[$aid]"
      echo -n " ${mid}. ${!tmp}" | sed -n 's/ ->/\//p'
    fi
    prev=${mid}
  done
  echo ""
}

function selection_to_cmd(){
  CMD=''
  SELECTION_ERR=''

  local ci=${1##*,} #get the command index
  let ci=ci-1 || true;      #arrays are 0 based, menu is starts from 1

  case ${1} in
      '0')   options=("${menu0[@]}");;
      '0,1') options=("${menu1[@]}");;
      '0,2') options=("${menu2[@]}");;
      '0,3') options=("${menu3[@]}");;
      '0,4') options=("${menu4[@]}");;
      '0,5') options=("${menu5[@]}");;
      '0,6') options=("${menu6[@]}");;
      '0,1,1') options=("${menu11[@]}");;
      '0,1,2') options=("${menu12[@]}");;
      '0,1,3') options=("${menu13[@]}");;
      '0,1,4') options=("${menu14[@]}");;
      '0,1,5') options=("${menu15[@]}");;
      '0,1,6') options=("${menu16[@]}");;
      '0,1,7') options=("${menu17[@]}");;
      '0,1,8') options=("${menu18[@]}");;
      '0,1,9') options=("${menu19[@]}");;

      #execute menu1x command
      '0,1,1,'*) CMD="${cmds11[$ci]}";;
      '0,1,2,'*) CMD="${cmds12[$ci]}";;
      '0,1,3,'*) CMD="${cmds13[$ci]}";;
      '0,1,4,'*) CMD="${cmds14[$ci]}";;
      '0,1,5,'*) CMD="${cmds15[$ci]}";;
      '0,1,6,'*) CMD="${cmds16[$ci]}";;
      '0,1,7,'*) CMD="${cmds17[$ci]}";;
      '0,1,8,'*) CMD="${cmds18[$ci]}";;
      '0,1,9,'*) CMD="${cmds19[$ci]}";;

      '0,2,'*) CMD="${cmds2[$ci]}";;
      '0,3,'*) CMD="${cmds3[$ci]}";;
      '0,4,'*) CMD="${cmds4[$ci]}";;
      '0,5,'*) CMD="${cmds5[$ci]}";;
      '0,6,'*) CMD="${cmds6[$ci]}";;
      *)
        SELECTION_ERR='yes'
        echo "Error: Invalid SELECTION";;
  esac
}

function exec_CMD(){

  set +e; #disable error flag

  #if its an internal command
  if [ ${CMD:0:1} == '_' ]; then
    #internal command may change global variables, so they can't run in subshell, or be piped!
    ${1}

  elif [ "${TARGET_HOST}" ]; then
    OUTFILENAME="$(date '+%d-%m-%Y_%T')_${TARGET_HOST}_${SELECTION//,/.}.txt"
    ssh -p${TARGET_PORT} ${TARGET_USER}@${TARGET_HOST} "cd ${REMOTE_HOME}; ./forensics.sh ${SELECTION}" 2>&1 | tee "${EVIDENCE_DIR}/${OUTFILENAME}"
  else
    OUTFILENAME="$(date '+%d-%m-%Y_%T')_localhost_${SELECTION//,/.}.txt"

    #TODO: this pipe creates a subshell, and all modified variables are not saved !!!
    eval ${1} 2>&1 | tee "${EVIDENCE_DIR}/${OUTFILENAME}"
  fi

  set -e; #enable error flag
}

function top_menu(){

  source ".menu_${MENU_LANG}.sh"

  options=("${menu0[@]}")

  local QUIT_ME=0
  local SELECTION='0'
  while [ ${QUIT_ME} -eq 0 ]; do

    show_menu_header ${SELECTION}

    if [ ${SELECTION} == '0' ]; then
      PS3="Please enter your choice[1-${#options[@]}, 99 to Quit]: "
    else
      PS3="Please enter your choice[1-${#options[@]}, 99 for Back]: "
    fi

    select opt in "${options[@]}"
    do

      # validate $REPLY is a number
      if [ -z "$(echo ${REPLY} | grep '^[0-9]\+$')" ]; then
        echo "invalid input ${REPLY}"
        break;
      fi

      #echo "${options[$((REPLY-1))]}"
      if [ "${REPLY}" == '99' ]; then
        if [ "${SELECTION}" == '0' ]; then
          QUIT_ME=1
          break;
        else
          SELECTION="${SELECTION%,*}"; #drop last menu section - 0:1:1:1 -> 0:1:1
        fi
      else
        SELECTION+=",${REPLY}"
      fi

      #echo "SELECTION=${SELECTION}"
      selection_to_cmd "${SELECTION}"
      if [ "${SELECTION_ERR}" ]; then
        echo "invalid option $REPLY"
        SELECTION='0'; #return to menu0
      else
        break;  #valid selection
      fi
    done

    if [ "${CMD}" ]; then
      exec_CMD "${CMD}"

      #remove index of executed command from section
      SELECTION="${SELECTION%,*}"; #drop last menu section - 0:1:1:1 -> 0:1:1
    fi

  done
}

function detect_os(){
  #opensuse,debian,slackware, ubuntu
  if [ -f /etc/os-release ]; then
    DISTRO=$(grep -m 1 ID /etc/os-release | cut -f2 -d= | tr -d '"')
    DISTRO_VER=$(grep VERSION_ID /etc/os-release | tr -d '"' | cut -f2 -d= | cut -f1 -d.)

  elif [ -f /etc/arch-release ]; then
		DISTO='arch'
		DISTRO_VER='';	#there is no release id in Arch !!!

	elif [ -f /etc/centos-release ]; then
		DISTRO='centos'
    if [ -f /etc/os-release ]; then
		    DISTRO_VER=$(grep VERSION_ID /etc/os-release | tr -d '"' | cut -f2 -d=)
    elif [ -f /etc/centos-release ]; then
      DISTRO_VER=$(cut -f3 -d' ' /etc/centos-release | cut -f1 -d.)
    fi

	elif [ -f /etc/debian_version ]; then
		DISTRO='debian'
		DISTRO_VER=$(grep VERSION_ID /etc/os-release | tr -d '"' | cut -f2 -d=)

	elif [ -f /etc/fedora-release ]; then
		DISTRO='fedora'
		DISTRO_VER=$(cut -f3 -d' ' /etc/fedora-release)

	elif [ -f /bin/freebsd-version ]; then
		DISTRO='freebsd'
		DISTRO_VER=$(freebsd-version | cut -f1 -d'-')

	elif [ -f /etc/sl-release ]; then
		DISTRO='scientific'
		DISTRO_VER=$(grep VERSION_ID /etc/os-release | tr -d '"' | cut -f2 -d= | cut -f1 -d.)

	else
		echo "Error: Failed to detect distribution";
    exit 1;
	fi
}

function detect_lang(){
  MENU_LANG=$(locale | grep -m 1 '^LANG=' | cut -f2 -d= | cut -f1 -d_)
  if [ -z "${MENU_LANG}" -o ! -f ".menu_${MENU_LANG}.sh" ]; then
    MENU_LANG='en'
  fi
}

#sets DISTRO and DISTRO_VER
function internal_init(){
  mkdir -p "${EVIDENCE_DIR}"

  detect_os;
  detect_lang;

  source ".cmds.sh"
}

function _generate_html_report(){
  REPORT_FILE='report.html'

  exec 6>&1           # Link file descriptor #6 with stdout.
                      # Saves stdout.

  exec > ${REPORT_FILE}     # stdout replaced with file "logfile.txt".

  cat << CMD_EOF
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
CMD_EOF

  cat utils/report.js
  cat utils/report.css
  echo "</head>"
  echo "<body>"

  NUM_COMMANDS=$(ls evidence/ | wc -w)
  echo "<p>Report generated on $(date), based on ${NUM_COMMANDS} evidence files.</p>"

  #generate left column
  cat <<CMD_EOF
  <div class="row">
  <div class="column left" style="background-color:#aaa;">
CMD_EOF

  for cmdfilename in $(ls evidence); do
    mid=$(echo ${cmdfilename} | cut -f4 -d_ | sed 's/\.txt//g' | cut -f2- -d.)
    cat <<CMD_EOF
    <div class="tab">
      <button class="tablinks" onclick="openCity(event, '${cmdfilename}')">${mid}</button>
    </div>
CMD_EOF
  done
  echo '</div>'; #end column left

  #generate right column
  echo '<div class="column right">'
  for cmdfilename in $(ls evidence); do
    mid=$(echo ${cmdfilename} | cut -f4 -d_ | sed 's/\.txt//g' | tr '.' ',')
    cmd_date=$(echo ${cmdfilename} | cut -f1,2 -d_)
    cmd_host=$(echo ${cmdfilename} | cut -f3 -d_)
    cmd_code=$(selection_to_cmd ${mid}; echo $CMD)

    cat <<CMD_EOF
    <div id="${cmdfilename}" class="tabcontent">
      <h3>[${cmd_date} @ ${cmd_host}] $ ${cmd_code} </h3>
      <p>$(cat evidence/${cmdfilename} | recode ascii..html | sed 's/$/<\/br>/g')</p>
    </div>
CMD_EOF
  done
  echo '</div>'
  echo -e '</body>\n</html>'

  exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
}

#End functions

internal_init;

cat << EOF

[*] Copyright Hristiyan Lazarov [*]


+--------------------------------------------------------------+
|  _______         _____                                       |
| |__   __|       |  __ \                                      |
|    | |_   ___  _| |__) |___  ___ _ __   ___  _ __  ___  ___  |
|    | | | | \ \/ /  _  // _ \/ __| '_ \ / _ \| '_ \/ __|/ _ \ |
|    | | |_| |>  <| | \ \  __/\__ \ |_) | (_) | | | \__ \  __/ |
|    |_|\__,_/_/\_\_|  \_\___||___/ .__/ \___/|_| |_|___/\___| |
|                                 | |                          |
|                                 |_|                          |
|							       |
+--------------------------------------------------------------+

[*] Linux Incident Response framework written in bash [*]


EOF
if [ $# -ge 1 ]; then
  selection_to_cmd "${1}"
  if [ "${CMD}" ]; then
    exec_CMD "${CMD}"
  fi
else
  top_menu;
fi
cat <<EOF

EOF
