#!/bin/bash

#https://www.haproxy.org/download/2.4/src/haproxy-2.4.4.tar.gz

LATEST_HAPROXY_FILE=haproxy-2.4.4.tar.gz
LATEST_HAPROXY=haproxy-2.4.4

### https://www.lua.org/ftp/lua-5.4.3.tar.gz

LATEST_LUA_FILE=lua-5.4.3.tar.gz
LATEST_LUA=lua-5.4.3

# make default instalation dir

mkdir /opt/haproxy

#lua

tar xzvf "${LATEST_LUA_FILE}"
cd "${LATEST_LUA}"
make INSTALL_TOP=/opt/haproxy/"${LATEST_LUA}" linux install



#haproxy
cd ../
tar xzvf "${LATEST_HAPROXY_FILE}"
yum install gcc-c++ openssl-devel pcre-static pcre-devel systemd-devel -y
cd "${LATEST_HAPROXY}"

make USE_NS=1 \
USE_TFO=1 \
USE_OPENSSL=1 \
USE_ZLIB=1 \
USE_LUA=1 \
USE_PCRE=1 \
USE_SYSTEMD=1 \
USE_LIBCRYPT=1 \
USE_THREAD=1 \
USE_LINUX_TPROXY=1 \
USE_GETADDRINFO=1 \
TARGET=linux-glibc \
LUA_INC=/opt/haproxy/"${LATEST_LUA}"/include \
LUA_LIB=/opt/haproxy/"${LATEST_LUA}"/lib 

make PREFIX=/opt/haproxy/"${LATEST_HAPROXY}" install

#make install

### add user group haproxy

groupadd -g 188 haproxy
useradd -g 188 -u 188 -d /var/lib/haproxy -s /sbin/nologin -c haproxy haproxy


############ make environtment file

cat > /etc/sysconfig/haproxy-2.4.4 << 'EOL'
# Command line options to pass to HAProxy at startup
# The default is:
#CLI_OPTIONS="-Ws"
CLI_OPTIONS="-Ws"

# Specify an alternate configuration file. The default is:
#CONFIG_FILE=/etc/haproxy/haproxy-2.4.4.conf
CONFIG_FILE=/etc/haproxy/haproxy.cfg

# File used to track process IDs. The default is:
#PID_FILE=/var/run/haproxy-2.4.4.pid
PID_FILE=/var/run/haproxy.pid
EOL

############### make sevice file

cat > /etc/systemd/system/haproxy.service << 'EOL'
[Unit]
Description=HAProxy Load Balancer (2.4.4)
After=syslog.target network.target


[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/haproxy-2.4.4
ExecStartPre= /opt/haproxy/haproxy-2.4.4/sbin/haproxy -f $CONFIG_FILE -c -q
ExecStart=/opt/haproxy/haproxy-2.4.4/sbin/haproxy -f $CONFIG_FILE -p $PID_FILE $CLI_OPTIONS
ExecReload=/bin/kill -USR2 $MAINPID
ExecStop=/bin/kill -USR1 $MAINPID
KillMode=mixed
Restart=always
SuccessExitStatus=143


[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload

############ make dir & config file

mkdir /etc/haproxy

cat > /etc/haproxy/haproxy.cfg << 'EOL'
global
        daemon
        log         127.0.0.1 local2     #Log configuration
        chroot      /var/lib/haproxy
        pidfile     /var/run/haproxy.pid
        maxconn     4000
        user        haproxy
        group       haproxy
        stats socket /var/lib/haproxy/stats

defaults
        mode                    http
        log                     global
        option                  tcplog
        option              dontlognull
        retries             3
        maxconn                 10000
        option              redispatch
        timeout connect 4s
        timeout client 5m
        timeout server 5m

listen stats
bind *:7000
        mode http
        option forwardfor
        option httpclose
        stats enable
        stats show-legends
        stats refresh 5s
        stats uri /
        stats realm Haproxy\ Statistics
        stats auth loadbalancer:loadbalancer
        stats admin if TRUE
         
listen FrontendName
bind 192.168.77.100:80,192.168.77.100:443
        mode tcp
        option tcplog
        balance leastconn
        stick on src
        stick-table type ip size 10240k expire 30m
        server RIPName0 192.168.77.200 check port 80 inter 10s rise 2 fall 3
        server RIPName1 192.168.77.201 check port 80 inter 10s rise 2 fall 3
EOL
