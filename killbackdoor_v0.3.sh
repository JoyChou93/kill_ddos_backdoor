#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# v0.1 -- update(20160413) add rc.local content
# v0.2 -- update(20160414) add /etc/crontab content && del redis syss backdoor
# v0.3 -- update(20160517) 修复判断文件被删除的进程bug（之前版本存在文件存在也会被判断成deleted process）

function display_author(){
    echo -e "\n"
    echo "+----------------------------------------------------------------------------------------+"
    echo "|            Aliyun_Security Linux Auto Backdoor killer && Intrusion Analysis            |"
    echo "|            Author:JoyChou                                                              |"
    echo "|            Date:2016.01.04                                                             |"
    echo "|            Version:0.3                                                                 |"
    echo "+----------------------------------------------------------------------------------------+"
    echo -e "\n"

}
#人工确认进程是否可以被kill
function check_is_exist_deleted_process(){
    deleted_process=`find /proc/ -name exe | xargs ls -l {} 2>/dev/null | grep deleted | awk '{print $11}' | sort | uniq | xargs ls -l {} 2>/dev/null`
    if [ -n "$deleted_process" ]; then
        echo $deleted_process
        read -p "确认上面的进程是否是能被kill的正常进程！能被kill按y，不能kill请按n . y/n  " yes_no
        if [ $yes_no == "n" ]
        then 
            echo "byebye"
            exit
        fi
    fi  


}
#根据pid判断文件是否存在，参数1是进程pid
function check_file_exist_by_pid(){
    res=`find /proc/ -name exe | xargs ls -l {} 2>/dev/null | grep $1 | awk '{print $11}' | sort | uniq | xargs ls -la {} 2>/dev/null`
    if [ -z "$res" ]; then
        return 0 #文件不存在
    else
        return 1 #文件存在
    fi
}

#说明下为什么不直接用/proc/的deleted的pid，
#因为会存在这样的情况：文件存在，但是/proc/exe显示deleted，原因暂时不明确
#所以最后deleted的进程是利用/proc/找到deleted的子集，只需再用ls判断即可
function kill_deleted_process(){
    #先得到/proc/的deleted进程pid，再判断这些pid的文件是否存在，如果不存在则kill进程
    find /proc/ -name exe | xargs ls -l 2>/dev/null  | grep deleted| awk '{print $9}' | awk -F / '{print $3}' | sort | uniq | while read line
    do
        check_file_exist_by_pid $line
        if [[ $? == 0 ]]; then
            kill -9 $line
        fi
    done

}
function check_is_root(){
    if [ $(id -u) != "0" ]; then
        echo "Error: You must be root to run this script"
        exit 1
    else 
        echo "Hi,root"
    fi  
}

        
function check_mysql_udf(){
    #check mysql UDF
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist mysql UDF and mysql webshell.\033[0m"
    #mysql's so privilege is root, not mysql
    mysql_udf=`find / -regex '.*\.\(so\|php\|jsp\|py|perl\|c\)' -type f -user mysql | xargs -i ls -lat {}`
    if [ -z "$mysql_udf" ];then
        echo "[-]Mysql have no UDF found."
    else
        echo -e "\033[31m[+]Find Mysql UDF\033[0m"
        echo "$mysql_udf"
    fi
}


function check_redis_conf(){
    echo -e "\n"
    echo -e "\033[36mNow, checking redis config\033[0m"
    bind=`find / -name redis.conf | xargs -i grep -E "(^#\sbind\s127\.0\.0\.1)" {}`
    requirepass=`find / -name redis.conf | xargs -i grep -E "(^#\srequirepass.*)" {}`
    if [ -n "$bind" ] && [ -n "$requirepass" ] # 不加引号会报错：[: too many arguments(变量有空格就会报这个错)  -n表示字符串不等于空
    then
        echo -e "\033[31m[+]Redis config is wrong!\033[0m"
        echo -e "\033[31m$bind\033[0m"
        echo -e "\033[31m$requirepass\033[0m"
    else
        echo "[-]Redis is secure or not install redis service"
    fi
}

function check_redis_sshkey_backdoor(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist redis ssh authorized_keys backdoor.\033[0m"
    sshkey_backdoor=`strings /root/.ssh/authorized_keys 2>/dev/null | grep REDIS`
    if [ -z $sshkey_backdoor ];then # -z mean zero
        echo "[-]Not find redis ssh authorized_keys backdoor"
    else   
        rm -rf /root/.ssh
        echo -e "\033[31m[+]Find redis ssh authorized_keys backdoor and delete it already \033[0m"
    fi
}

function del_redis_syss_backdoor(){
    check_redis_syss_backdoor
    if [ $? == 1 ]; then
        echo -e "\033[31m[+]Find syss system account backdoor\033[0m"
        echo -e "\033[31m$syss\033[0m"
    else 
        echo "[-]Not find syss system account backdoor"
        return
    fi
    #change syss id number
    sed -i "s/syss:x:0:0/syss:x:3:3/g" /etc/passwd
    userdel syss
    if [ -f /var/lib/.ssh/authorized_keys ]; then
        chattr -i /var/lib/.ssh/authorized_keys
        rm -rf /var/lib/.ssh
    fi
    
    syss=`cat /etc/passwd | grep syss | grep /var/lib`
    if [ -z "$syss" ]; then
        echo -e "\033[31m[+]success to detele syss system account backdoor\033[0m"
    else
        echo "[-]fail to delete syss system account backdoor"
    fi
}

function check_redis_syss_backdoor(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist redis syss system account backdoor.\033[0m" 
    syss=`cat /etc/passwd | grep syss | grep /var/lib`
    if [ -z "$syss" ]; then
        return 0
    else
        return 1
    fi
}
#判断是否有redis勒索比特币的登录信息
#http://pastie.org/pastes/10800563/text?key=hzzm4hk4ihwx1jfxzfizzq
function check_redis_btcoin_motd(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist redis bitcoin backdoor.\033[0m" 
    btcoin=`cat /etc/motd | grep http://pastie.org/pastes`
    if [ -z "$btcoin" ]; then
        echo "[-]Not find redis btcoin backdoor"
    else
        echo -e "\033[31m[+]Find redis btcoin backdoor\033[0m"
        echo -e "\033[31m$btcoin\033[0m"
        #替换成空
        sed -i 's/Hi, please.*http:\/\/pastie\.org\/p.*\s*//g' /etc/motd
    fi
}
function display_rc_local(){
    echo -e "\n"
    echo -e "\033[36mNow, display rc.local.\033[0m"
    start_content=`cat /etc/rc.local`
    echo "$start_content"
}

function display_etc_crontab(){
    echo -e "\n"
    echo -e "\033[36mNow, display /etc/crontab.\033[0m"
    crontab=`cat /etc/crontab`
    echo "$crontab" 
}
#check postgresql weak password backdoor
function check_postgresql_weak_pwd_bd(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist postgresql backdoor.\033[0m"
    postgres=`find /tmp -regex 'linux\(32|64\)' -user postgres | xargs -i ls -lat {}`
    if [ -z "$postgres" ];then
        echo "[-]Not find postgres backdoor"
    else 
        echo -e "\033[31m[+]Find postgres backdoor\033[0m"
        echo "$postgres"
    fi
}

#check if exist /tmp/ok backdoor
function Is_Exist_tmpok_backdoor(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist /tmp/ok backdoor.\033[0m"
    #获取文件被deleted的进程pid
    process=`find /proc/ -name exe | xargs ls -l 2>/dev/null  | grep deleted| awk '{print $9}' | awk -F / '{print $3}' | sort | uniq`
    if [ -n "$process" ]; then
        #获取文件被deleted的进程pid的进程名
        result=`ps -ef | awk '$2==$process{print}'`
        #判断如果为空，那么是/tmp/ok木马
        if [ -z "$result" ]; then
            echo -e "\033[31m[+]Find /tmp/ok backdoor\033[0m"
            Kill_Tmpok_Backdoor
        else
            echo "[-]Not find /tmp/ok backdoor"
        fi
    else
        echo "[-]Not find /tmp/ok backdoor"
    fi
    
}

function Kill_Tmpok_Backdoor(){
    #由于直接delete文件被删除的pid，会有误报，所以要显示下确认！
    del_gates_process=`find /proc/ -name exe | xargs ls -l 2>/dev/null  | grep deleted| awk '{print $11}' | sort | uniq`
    echo -e "\n"
    echo -e "\033[31m$del_gates_process\033[0m"
    read -p "Make sure if delete all of these process? y/n  " yes_no
    if [ $yes_no == "y" ]
    then
        find /proc/ -name exe | xargs ls -l 2>/dev/null  | grep deleted| awk '{print $9}' | awk -F / '{print $3}' | sort | uniq | xargs kill -9
    fi
}

function killgates(){
    ps_size=`ls -la /bin/ps | awk '{print $5}'`
    netstat_size=`ls -la /bin/netstat | awk '{print $5}'`
    
    if [ -f "/bin/ps" ] && [ $ps_size -gt 1100000 ] 
    then
        ps_backdoor=`ls -la /bin/ps | awk '{print $5}' | xargs -i find / -type f -size {}c 2>/dev/null | xargs ls -la`
        echo -e "\033[31m$ps_backdoor\033[0m"
        read -p "Make sure if delete all of them-1? y/n  " yes_no
        if [ $yes_no == "y" ]
        then 
            ls -la /bin/ps | awk '{print $5}' | xargs -i find / -type f -size {}c 2>/dev/null | xargs rm 
        fi
    fi
        
    
    if [ -f "/bin/netstat" ] && [ $netstat_size -gt 1100000 ] && [ "$ps_size" != "$ps_netstat" ];then
        netstat_backdoor=`ls -la /bin/netstat | awk '{print $5}' | xargs -i find / -type f -size {}c 2>/dev/null | xargs ls -la`
        echo -e "\033[31m$netstat_backdoor\033[0m"
        read -p "Make sure if delete all of them-2? y/n  " yes_no
        if [ $yes_no == "y" ];then 
            ls -la /bin/netstat | awk '{print $5}' | xargs -i find / -type f -size {}c 2>/dev/null | xargs rm 
        fi  
    fi
    
    #显示 1223123 大小的gates马，并且删除
    gatebackdoors=`find / -type f -size 1223123c 2>/dev/null`   
    #如果存在1223123大小的马
    if [ -n "$gatebackdoors" ] #不加引号的话，返回如果是换行也表示不为空。加上引号就不会了。
    then 
        gatebackdoors=`find / -type f -size 1223123c 2>/dev/null | xargs ls -la`
        echo -e "\033[31m$gatebackdoors\033[0m"
        read -p "Make sure if delete all of them-3? y/n  " yes_no
        if [ $yes_no == "y" ]
        then
            find / -type f -size 1223123c 2>/dev/null | xargs rm -rf
        fi
    fi
    
    chattr_init=`ls -la /etc/init.d | awk '{print $11}'`
    if [ $chattr_init == "rc.d/init.d" ]
    then 
        chattr -i /etc/rc.d/init.d
    else
        chattr -i /etc/init.d
    fi

    if [ -f "/etc/init.d/DbSecuritySdt" ]
    then
        cat /etc/init.d/DbSecuritySdt | while read line
        do
            rm -rf $line
        done
    fi

    if [ -f "/etc/init.d/DbSecuritySpt" ]
    then
        cat /etc/init.d/DbSecuritySpt | while read line
        do
            rm -rf $line
        done
    fi

    if [ -f "/etc/init.d/DbSecurityMdt" ]
    then
        cat /etc/init.d/DbSecurityMdt | while read line
        do
            rm -rf $line
        done
    fi

    if [ -f "/etc/init.d/selinux" ]
    then
        cat /etc/init.d/selinux | while read line
        do
            rm -rf $line
        done
    fi


    chattr -i /usr/bin
    rm -rf /usr/bin/.sshd
    rm -rf /usr/bin/.swhd
    rm -rf /usr/bin/bsd-port
    \cp /usr/bin/dpkgd/ps /bin/ps
    \cp /usr/bin/dpkgd/netstat /bin/netstat 
    \cp /usr/bin/dpkgd/lsof /usr/sbin/lsof
    \cp /usr/bin/dpkgd/ss /usr/sbin/ss
    rm -f /etc/init.d/DbSecuritySpt
    rm -f /etc/init.d/DbSecuritySdt
    rm -f /etc/init.d/DbSecurityMdt
    rm -f /etc/init.d/selinux 
    rm -f /tmp/gates.lod
    rm -f /tmp/moni.lod 
    rm -f /tmp/conf.d
    #由于直接delete文件被删除的pid，会有误报，所以要显示下确认！
    del_gates_process=`find /proc/ -name exe | xargs ls -l {} 2>/dev/null | grep deleted | awk '{print $11}' | sort | uniq | xargs ls -la {} 2>/dev/null`
    echo -e "\n"
    echo -e "\033[31m$del_gates_process\033[0m"
    read -p "Make sure if delete all of these process? y/n  " yes_no
    if [ $yes_no == "y" ]
    then
        kill_deleted_process
    fi
}

function check_exist_gates_bd(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist gates backdoor.\033[0m"
    ps_filesize=`ls -la /bin/ps | awk '{print $5}'`
    ps_netstat=`ls -la /bin/netstat | awk '{print $5}'`
    selinux_file="/etc/init.d/selinux"
    DbSecuritySpt_file="/etc/init.d/DbSecuritySpt"
    if [ $ps_filesize == 1223123 ] || [ -f $selinux_file ] || [ -f $DbSecuritySpt_file ] || [ $ps_netstat ==  1135000 ]
    then
        echo -e "\033[31m[+]Find gates backdoor\033[0m"
        killgates
    else
        echo "[-]Not find gates backdoor"
    fi  
}

function is_xorddos_backdoor_feature(){
    ua_feature=`strings $1 | grep "TencentTraveler"`
    cron_feature=`strings $1 | grep "BB2FA36AAA9541F0"`

    kill_sh_feature=`strings $1 | grep "/etc/cron.hourly/kill.sh"`

    cron_sh_feature=`strings $1 | grep "/etc/cron.hourly/cron.sh"`

    hacker_feature=`strings $1 | grep "Hacker"`
    devicemac_feature=`strings $1 | grep "device mac"`

    if [ -n "$kill_sh_feature" ]; then
        return 1
    fi

    if [ -n "$ua_feature" ] && [ -n "$cron_feature" ]; then
        return 1
    fi

    if [ -n "$cron_sh_feature" ]; then
        return 1
    fi

    if [ -n "$hacker_feature" ] && [ -n "$devicemac_feature" ]; then
        return 1
    fi
       
    return 0
}

function is_xorddos_etc_initd_bd(){
    ten_backdoor=`cat $1 | grep '[a-z]\{10\}' | grep description | awk '{print $3}'`
    ten_backdoor_path="/usr/bin/"${ten_backdoor}
    is_xorddos_backdoor_feature $ten_backdoor_path
    if [ $? == 1 ]; then
        return 1
    else
        return 0
    fi
}

function is_xorddos(){
    echo -e "\n"
    echo -e "\033[36mNow, checking if exist xorddos backdoor.\033[0m"
    cron_sh="/etc/cron.hourly/cron.sh"
    gcc_sh="/etc/cron.hourly/gcc.sh"
    kill_sh="/etc/cron.hourly/kill.sh"
    gcc4_sh="/etc/cron.hourly/gcc4.sh"
    if [ -f $cron_sh ] || [ -f $gcc_sh ] || [ -f $kill_sh ] || [ -f $gcc4_sh ]
    then
        echo -e "\033[31m[+]Find xorddos backdoor\033[0m"
        display_xorddos
    else
        echo "[-]Not find xorddos backdoor"
    fi
}

function display_xorddos(){
    cron_sh="/etc/cron.hourly/cron.sh"
    gcc_sh="/etc/cron.hourly/gcc.sh"
    kill_sh="/etc/cron.hourly/kill.sh"
    gcc4_sh="/etc/cron.hourly/gcc4.sh"
    cron_backdoor=""

    if [ -f $cron_sh ]
    then
        cron_backdoor=$cron_sh
        xorddos_sh=`ls -la $cron_backdoor | awk '{print $5}'`
        # cron_sh文件内容有为空的情况，所以加个判断文件大小是否为空
        if [ 0 != "$xorddos_sh" ]
        then
            kill_xorddos $cron_sh
        else
            echo -e "\033[31m[+]Xorddos backdoor_sh filesize is zero\033[0m"
        fi
    fi
    
    if [ -f $gcc_sh ]
    then
        cron_backdoor=$gcc_sh
        xorddos_sh=`ls -la $cron_backdoor | awk '{print $5}'`
        # cron_sh文件内容有为空的情况，所以加个判断文件大小是否为空
        if [ 0 != "$xorddos_sh" ]
        then
            kill_xorddos $gcc_sh
        else
            echo -e "\033[31m[+]Xorddos backdoor_sh filesize is zero\033[0m"
        fi
    fi
    
    if [ -f $kill_sh ]
    then
        cron_backdoor=$kill_sh
        xorddos_sh=`ls -la $cron_backdoor | awk '{print $5}'`
        # cron_sh文件内容有为空的情况，所以加个判断文件大小是否为空
        if [ 0 != "$xorddos_sh" ]
        then
            kill_xorddos $kill_sh
        else
            echo -e "\033[31m[+]Xorddos backdoor_sh filesize is zero\033[0m"
        fi
    fi

    if [ -f $gcc4_sh ]
    then
        cron_backdoor=$gcc4_sh
        xorddos_sh=`ls -la $cron_backdoor | awk '{print $5}'`
        # cron_sh文件内容有为空的情况，所以加个判断文件大小是否为空
        if [ 0 != "$xorddos_sh" ]; then
            kill_xorddos $gcc4_sh
        else
            echo -e "\033[31m[+]Xorddos backdoor_sh filesize is zero\033[0m"
        fi
    fi
}

function kill_xorddos(){
    #先找到/etc/cron.hourly/里面的sh的木马文件，再利用find命令找到大小相同的
    cat $1 | grep cp | awk '{print $2}' | xargs ls -la | awk '{print $5}' | xargs -i find / -type f -size {}c 2>/dev/null | while read line
    do
        is_xorddos_backdoor_feature $line
        if [ $? == 1 ] ; then
            echo -e "\033[31m[Default deleted] $line\033[0m"
            rm $line
        fi
    done

    #删除kill.sh
    echo -e "\033[31m[Default deleted] $1\033[0m"
    rm -rf $1
    
    #删除/ect/init.d/的木马服务和文件
    ls -lat /etc/init.d/ | head -20 | awk '{print $9}' | grep '^[a-z]\{10\}$' | while read line
    do
        etc_initd_backdoor="/etc/init.d/"${line}
        echo $etc_initd_backdoor
        is_xorddos_etc_initd_bd $etc_initd_backdoor
        if [ $? == 1 ]; then
            echo -e "\033[31m[Default deleted] $etc_initd_backdoor\033[0m"
            rm $etc_initd_backdoor
        fi
    done

    #删除/bin的10位随机生成的backdoor
    ls -lat /bin | head -20 | awk '{print $9}' | grep '^[a-z]\{10\}$' | while read line
    do
        #字符串拼接
        bin_ten_xorddos="/bin/"${line}
        is_xorddos_backdoor_feature $bin_ten_xorddos
        if [ $? == 1 ]; then
            echo -e "\033[31m[Default deleted] $bin_ten_xorddos\033[0m"
            rm $bin_ten_xorddos
        fi
    done


    #删除/usr/bin的10位随机生成的backdoor
    ls -lat /usr/bin | head -20 | awk '{print $9}' | grep '^[a-z]\{10\}$' | while read line
    do
        #字符串拼接
        bin_ten_xorddos="/usr/bin/"${line}
        is_xorddos_backdoor_feature $bin_ten_xorddos
        if [ $? == 1 ]; then
            echo -e "\033[31m[Default deleted] $bin_ten_xorddos\033[0m"
            rm $bin_ten_xorddos
        fi
    done

    #删除/boot的10位随机生成的backdoor
    ls -lat /boot | head -20 | awk '{print $9}' | grep '^[a-z]\{10\}$' | while read line
    do
        #字符串拼接
        bin_ten_xorddos="/boot/"${line}
        is_xorddos_backdoor_feature $bin_ten_xorddos
        if [ $? == 1 ]; then
            echo -e "\033[31m[Default deleted] $bin_ten_xorddos\033[0m"
            rm $bin_ten_xorddos
        fi
    done

    #删除大小是619090c的xorddos backdoor
    find / -type f -size 619090c 2>/dev/null | while read line
    do
        is_xorddos_backdoor_feature $line
        if [ $? == 1 ] ; then
            echo -e "\033[31m[Default deleted] $line\033[0m"
            rm $line
        fi
    done

    chattr +i /etc/cron.hourly
    chattr +i /bin
    chattr +i /usr/bin

    chattr_init=`ls -la /etc/init.d | awk '{print $11}'`
    if [ $chattr_init == "rc.d/init.d" ]
    then 
        chattr +i /etc/rc.d/init.d
    else
        chattr +i /etc/init.d
    fi
    
    kill_deleted_process
    
    chattr -i /etc/cron.hourly
    chattr -i /bin 
    chattr -i /usr/bin
    if [ $chattr_init == "rc.d/init.d" ]
    then 
        chattr -i /etc/rc.d/init.d
    else
        chattr -i /etc/init.d
    fi
}

function fuck_done(){
    echo -e "\n[-]Fuck done\n"
}

display_author
check_is_exist_deleted_process
check_is_root
display_rc_local
display_etc_crontab
#check_mysql_udf
#check_redis_conf
check_redis_sshkey_backdoor
del_redis_syss_backdoor
check_redis_btcoin_motd
check_exist_gates_bd
is_xorddos
fuck_done




