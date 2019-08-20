#strings list of commands. Separator is ;
cmds11=(
'hostnamectl; who -b; uname -a; uptime; ifconfig; date; last reboot'
)

cmds12=(
'df -h'
'find /usr/bin -type f -exec file "{}" \; | grep -i "elf" | cut -f1 -d: | xargs -I "{}" -n 1 md5sum {}'
'modified_files_period_select'
'find / -type d -name "\.*"'
'find / \( -nouser -o -nogroup \) -exec ls -l {} \; 2>/dev/null'
'packaged_files_changed')

cmds13=('chkrootkit' 'yara_select' 'exiftool_select')

cmds14=(
'ps -axu'
'ls -alR /proc/*/exe 2> /dev/null | grep deleted'
'ss -tunap | sed "s/[ \t]\+/|/g"'
'dump_process_select'
'ls -alR /proc/*/cwd 2> /dev/null | grep -E "tmp|dev"')

cmds15=('netstat -nalp; netstat -plant')
cmds16=('w' 'getent passwd')
cmds17=('cat ~/.bash_history | nl')
cmds18=('list_all_crontab' 'list_all_onstartup')
cmds19=('cat_all_bash_history' 'grep [[:cntrl:]] /var/log/*.log')

cmds2=('_enter_target_details' '_target_cleanup' 'show_distro_ver')
cmds3=('_create_mem_image')
cmds4=('_create_disk_image')
cmds5=('_generate_html_report')
cmds6=('init_deps' '_init_yara' '_init_exiftool' 'init_check' '_init_chkrootkit' 'init_lime')

cmd_deps=(ssh fdisk sed grep cut sort uniq blockdev df tail pv rpm debsums tar gcore wget unzip tee locale)
