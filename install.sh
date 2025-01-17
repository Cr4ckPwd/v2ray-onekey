﻿#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author:	wulabing,breakwa2333
#	Dscription: V2ray ws+tls onekey 
#	Version: 1.0.1
#	Blog: https://www.wulabing.com
#	Official document: www.v2ray.com
#====================================================

#fonts color
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"

#生成伪装路径
camouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

source /etc/os-release

#从VERSION中提取发行版系统的英文名称，为了在debian/ubuntu下添加相对应的Nginx apt源
VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`

check_system(){
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
        echo -e "${OK} ${GreenBG} The current system is Centos ${VERSION_ID} ${VERSION} ${Font} "
        INS="yum"
        echo -e "${OK} ${GreenBG} SElinux 设置中，请耐心等待，不要进行其他操作${Font} "
        setsebool -P httpd_can_network_connect 1
        echo -e "${OK} ${GreenBG} SElinux 设置Finish ${Font} "
        ## Centos 也可以通过添加 epel 仓库来Install，目前不做改动
        cat>/etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF
        echo -e "${OK} ${GreenBG} Nginx 源 InstallFinish ${Font}" 
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
        echo -e "${OK} ${GreenBG} The current system is Debian ${VERSION_ID} ${VERSION} ${Font} "
        INS="apt"
        ## 添加 Nginx apt源
        if [ ! -f nginx_signing.key ];then
        echo "deb http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
        wget -nc https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
        fi
    elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
        echo -e "${OK} ${GreenBG} The current system is Ubuntu ${VERSION_ID} ${VERSION_CODENAME} ${Font} "
        INS="apt"
        ## 添加 Nginx apt源
        if [ ! -f nginx_signing.key ];then
        echo "deb http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
        wget -nc https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
        fi
    else
        echo -e "${Error} ${RedBG} The current system is ${ID} ${VERSION_ID} Not in the list of supported systems，Installation interrupted ${Font} "
        exit 1
    fi

}
is_root(){
    if [ `id -u` == 0 ]
        then echo -e "${OK} ${GreenBG} The current user is the root user，Enter the installation process ${Font} "
        sleep 3
    else
        echo -e "${Error} ${RedBG} The current user is not the root user, please switch to the root user and execute the script again ${Font}" 
        exit 1
    fi
}
judge(){
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} $1 Finish ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 Fail${Font}"
        exit 1
    fi
}
dependency_install(){
    ${INS} install wget git lsof -y

    if [[ "${ID}" == "centos" ]];then
       ${INS} -y install crontabs
    else
        ${INS} install cron
    fi
    judge "Install crontab"

    # 新版的IP判定不需要使用net-tools
    # ${INS} install net-tools -y
    # judge "Install net-tools"

    ${INS} install bc -y
    judge "Install bc"

    ${INS} install unzip -y
    judge "Install unzip"
}
port_alterid_set(){
    stty erase '^H' && read -p "Please enter the connection port（default:443）:" port
    [[ -z ${port} ]] && port="443"
    stty erase '^H' && read -p "Please enter alterID（default:64）:" alterID
    [[ -z ${alterID} ]] && alterID="64"
}
modify_port_UUID(){
    let PORT=$RANDOM+10000
    UUID=$(cat /proc/sys/kernel/random/uuid)
    sed -i "/\"port\"/c  \    \"port\":${PORT}," ${v2ray_conf}
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," ${v2ray_conf}
    sed -i "/\"alterId\"/c \\\t  \"alterId\":${alterID}" ${v2ray_conf}
    sed -i "/\"path\"/c \\\t  \"path\":\"\/${camouflage}\/\"" ${v2ray_conf}
}
modify_nginx(){
    ## sed 部分地方 适应新配置修正
    if [[ -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
    fi
    sed -i "/listen/{s/listen 443 ssl;/listen ${port} ssl;/}" ${v2ray_conf}
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf}
    sed -i "/location/c \\\tlocation \/${camouflage}\/" ${nginx_conf}
    sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${PORT};" ${nginx_conf}
    sed -i "/return/c \\\treturn 301 https://${domain}\$request_uri;" ${nginx_conf}
    sed -i "27i \\\tproxy_intercept_errors on;"  /etc/nginx/nginx.conf
}
web_camouflage(){
    ##请注意 这里和LNMP脚本的默认路径冲突，千万不要在Install了LNMP的环境下使用本脚本，否则后果自负
    rm -rf /home/webroot && mkdir -p /home/webroot && mkdir -p /home/webtemp && mkdir -p /home/webroot/jsproxy
    pathing=$[$[$RANDOM % 5] + 1] 
    wget https://github.com/breakwa2333/v2ray-onekey/blob/master/template/$pathing.zip?raw=true -O /home/webtemp/$pathing.zip
    unzip -d /home/webroot /home/webtemp/$pathing.zip
    judge "web 站点伪装"   
}
v2ray_install(){
    if [[ -d /root/v2ray ]];then
        rm -rf /root/v2ray
    fi

    mkdir -p /root/v2ray && cd /root/v2ray
    wget --no-check-certificate https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh
    
    if [[ -f install-release.sh ]];then
        bash install-release.sh --version v4.25.1
        judge "Install V2ray"
    else
        echo -e "${Error} ${RedBG} V2ray Install file download Fail, please check if the download address is available ${Font}"
        exit 4
    fi
}
nginx_install(){
    ${INS} install nginx -y
    if [[ -d /etc/nginx ]];then
        echo -e "${OK} ${GreenBG} nginx InstallFinish ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} nginx InstallFail ${Font}"
        exit 5
    fi
    if [[ ! -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        echo -e "${OK} ${GreenBG} nginx Initial configuration backup Finish ${Font}"
        sleep 1
    fi
}
ssl_install(){
    if [[ "${ID}" == "centos" ]];then
        ${INS} install socat nc -y        
    else
        ${INS} install socat netcat -y
    fi
    judge "Install SSL Certificate Generation"

    curl  https://get.acme.sh | sh
    judge "Install SSL Certificate Generation"

}
domain_check(){
    stty erase '^H' && read -p "Please enter Domain (eg:www.v2ray.com):" domain
    echo -e "${OK} ${GreenBG} Getting public IP information, please wait patiently ${Font}"
    domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_ip=`curl -4 ip.sb`
    echo -e "Domain name dns resolution IP：${domain_ip}"
    echo -e "Public IP : ${local_ip}"
    sleep 2
    if [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
        echo -e "${OK} ${GreenBG} The domain name dns resolution IP match the IP of the machine ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} The domain name dns resolution IP does not match the IP of the machine. Do you want to continue the installation?（y/n）${Font}" && read install
        case $install in
        [yY][eE][sS]|[yY])
            echo -e "${GreenBG} Continue Install ${Font}" 
            sleep 2
            ;;
        *)
            echo -e "${RedBG} Install Done ${Font}" 
            exit 2
            ;;
        esac
    fi
}

port_exist_check(){
    if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 The port is inactive. ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG}It is detected that port $1 is occupied. The following is the occupancy information for port $1 ${Font}"
        lsof -i:"$1"
        echo -e "${OK} ${GreenBG} After 5s, it will try to kill the occupied process automatically. ${Font}"
        sleep 5
        lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill Finish ${Font}"
        sleep 1
    fi
}

acme(){
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-384 --force
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} SSL Certificate generated successfully ${Font}"
        sleep 2
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
        if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} Certificate configuration is successful ${Font}"
        sleep 2
        fi
    else
        echo -e "${Error} ${RedBG} SSL Certificate Generation Fail ${Font}"
        exit 1
    fi
}
v2ray_conf_add(){
    mkdir -p /etc/v2ray && cd /etc/v2ray
    wget https://raw.githubusercontent.com/breakwa2333/v2ray-onekey/master/tls/config.json -O config.json
    modify_port_UUID
    judge "V2ray Configuration modification"
}
nginx_conf_add(){
    touch ${nginx_conf_dir}/v2ray.conf
    cat>${nginx_conf_dir}/v2ray.conf<<EOF
    server {
        listen 443 ssl;
        ssl on;
        ssl_certificate       /etc/v2ray/v2ray.crt;
        ssl_certificate_key   /etc/v2ray/v2ray.key;
        ssl_protocols         TLSv1.3;
        ssl_ciphers           AESGCM;
        server_name           serveraddr.com;
        index index.html index.htm;
        root  /home/webroot;
        error_page 400 = /400.html;
        location /ray/ 
        {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        }
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
    server {
        listen 80;
        server_name serveraddr.com;
        return 301 https://use.shadowsocksr.win\$request_uri;
    }
EOF

modify_nginx
judge "Nginx Configuration modification"

}

start_process_systemd(){
    ### nginx服务在InstallFinish后会自动启动。需要通过restart或reload重新加载配置
    systemctl start nginx 
    judge "Nginx 启动"


    systemctl start v2ray
    judge "V2ray 启动"
}

cron_update(){
    if [[ "${ID}" == "centos" ]];then
        sed -i "/acme.sh/c 0 0 * * 0 systemctl stop nginx && \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
        > /dev/null && systemctl start nginx " /var/spool/cron/root
    else
        sed -i "/acme.sh/c 0 0 * * 0 systemctl stop nginx && \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
        > /dev/null && systemctl start nginx " /var/spool/cron/crontabs/root
    fi
    echo "0 16 * * * root reboot" >> /etc/crontab
    if [[ "${ID}" == "centos" ]];then
        service crond restart
    else
        service cron restart
    fi
    judge "cron 计划任务更新"
}
show_information(){
    clear

    echo -e "${OK} ${Green} V2ray+ws+tls Installsuccess  "
    echo -e "${Red} V2ray configuration information ${Font}"
    echo -e "${Red} Address : ${Font} ${domain} "
    echo -e "${Red} Port：${Font} ${port} "
    echo -e "${Red} Userid（UUID）：${Font} ${UUID}"
    echo -e "${Red} AlterId：${Font} ${alterID}"
    echo -e "${Red} Encryption（security）：${Font} adaptive "
    echo -e "${Red} Transfer Protocol（network）：${Font} ws "
    echo -e "${Red} Camouflage type：${Font} none "
    echo -e "${Red} Path (don't fall/)：${Font} /${camouflage}/ "
    echo -e "${Red} Underlying transport security：${Font} tls "

    

}

install_bbr_plus(){
    bash -c "$(wget --no-check-certificate -qO- https://github.com/Aniverse/TrCtrlProToc0l/raw/master/A)"
}

main(){
    is_root
    check_system
    dependency_install
    domain_check
    port_alterid_set
    port_exist_check 80
    port_exist_check ${port}
    v2ray_install
    nginx_install
    v2ray_conf_add
    nginx_conf_add
    web_camouflage

    #改变证书Install位置，防止端口冲突关闭相关应用
    systemctl stop nginx
    systemctl enable v2ray.service
    systemctl stop v2ray
    
    #将证书生成放在最后，尽量避免多次尝试脚本从而造成的多次证书申请
    ssl_install
    acme
    
    show_information
    start_process_systemd
    cron_update
}

main
