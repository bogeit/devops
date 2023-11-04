#!/bin/bash
# __author__: bogeit

Help(){
    echo "Usage:"
    echo "bash $0 ssh   (1.1.1.1|ip.txt) off 'ip r'"
    echo "bash $0 rsync (1.1.1.1|ip.txt) off local_dir      remote_dir"
    echo "bash $0 hss   (1.1.1.1|ip.txt) off local_save_dir remote_dir"

    exit 0
}

if [ $# -eq 0 ];then
    Help
fi


control="${1}"
ip_file="${2}"
waitStatus="${3:-on}"
cmd_dir="${4}"
remote_dir="${5}"


wait_enter(){
    if [[ $waitStatus == "on" ]];then
        echo "  ======== wait a monment, you can use CTRL+C to stop this step or Enter to continue. ========"
        read -p "" Wait_a_moment
    else
        echo ">>>"
    fi
}



only_ip_add(){
    hosts_file_check
    [ -f ${hosts_file}_onlyip ] && > ${hosts_file}_onlyip
    for i in `seq 0 $(expr $(cat ${hosts_file} |jq -r '."instanceIP"|keys|length') - 1)`
    do
    {
        api_ip=`cat ${hosts_file} |jq -r ".instanceIP[$i]"`
        echo "${api_ip}" >> ${hosts_file}_onlyip
    }&
    done
    wait
}


pssh_check(){
  if [ ! -f /etc/redhat-release ] && cat /etc/issue|grep -iw Ubuntu &>/dev/null;then
    if ! which parallel-rsync &>/dev/null;then
      apt-get install -y pssh
    fi
    ssh_cmd="$(which parallel-ssh)"
    rsync_cmd="$(which parallel-rsync)"
    hss_cmd="$(which parallel-slurp)"
  else
    if ! which pssh &>/dev/null;then
      yum install -y pssh
    fi
    ssh_cmd="$(which pssh)"
    rsync_cmd="$(which prsync)"
    hss_cmd="$(which pslurp)"
  fi
}

pssh_func(){
  echo "ssh to host excute command"
  echo "Usage: $0 ssh   ip or ip_file {on|off} \"command\""
  echo -e "Example:  xxxctl ssh   1.1.1.1 off 'ip r'\n"
  wait_enter
  pssh_check
  [ -f ${ip_file} ] && ${ssh_cmd} -O ConnectTimeout=1 -O StrictHostKeyChecking=no -P -h ${ip_file} -l $(whoami) ${cmd_dir} || ${ssh_cmd} -O ConnectTimeout=1 -O StrictHostKeyChecking=no -P -H ${ip_file} -l $(whoami) ${cmd_dir}
}

prsync_func(){
  echo "rsync local files to remote host"
  echo "Usage: $0 rsync   ip or ip_file {on|off}   local_file or dir   remote_dir"
  echo -e "Example:  xxxctl rsync 1.1.1.1 off local_dir      remote_dir\n"
  wait_enter
  pssh_check
  [ -f ${ip_file} ] && ${rsync_cmd} -O ConnectTimeout=1 -O StrictHostKeyChecking=no -h ${ip_file} -l $(whoami) -a -r ${cmd_dir} ${remote_dir} || ${rsync_cmd} -O ConnectTimeout=1 -O StrictHostKeyChecking=no -H ${ip_file} -l $(whoami) -a -r ${cmd_dir} ${remote_dir}
}

pslurp_func(){
  echo "rsync remote host files to local"
  echo "Usage: $0 hss   ip or ip_file {on|off}   local_save_dir   remote_dir"
  echo -e "Example:  xxxctl hss   1.1.1.1 off local_save_dir remote_dir\n"
  wait_enter
  pssh_check
  [ ! -d ${cmd_dir} ] && mkdir -p ${cmd_dir}
  [ -f ${ip_file} ] && ${hss_cmd} -O ConnectTimeout=1 -O StrictHostKeyChecking=no -h ${ip_file} -l $(whoami) -r -L ${cmd_dir} ${remote_dir} $(basename ${remote_dir}) || ${hss_cmd} -O ConnectTimeout=1 -O StrictHostKeyChecking=no -H ${ip_file} -l $(whoami) -r -L ${cmd_dir} ${remote_dir} $(basename ${remote_dir})
}

main(){
    case $control in
        ssh)
        pssh_func
        ;;
        rsync)
        prsync_func
        ;;
        hss)
        pslurp_func
        ;;
        *)
        Help
    esac
}


main

