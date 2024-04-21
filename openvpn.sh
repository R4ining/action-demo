#!/bin/bash
#Author: zhang
#Time: 2024-04-21
#Version: v1.0
#Description: 创建 openvpn 账号，生成对应证书文件

set -eu

dir="/etc/openvpn/server/easy-rsa"
ca_dir="/etc/openvpn/server"
user_file="/etc/openvpn/server/user/psw-file"
parameter_num=$#
user=$1
pass=$2
vpn_server_ip=192.168.1.200
port=1194
function Usage(){
  if [ ! $parameter_num -eq 2 ];then
    echo "The Script Usage: ./$0 新建账号名称 新建账号密码"
    exit 1
  fi
}
function user_is_exist(){
  if [ ! -e $user_file ]; then
    touch ${user_file}
    chmod 600 ${user_file}
  fi
  grep -w $user $user_file &>/dev/null
  if [ $? -eq 0 ];then
    echo "用户 $user 已经存在"
    exit 1
  fi
}
function create_ca(){
  # 创建 客户端证书目录
  mkdir -p ${ca_dir}/$user
  if [ -d $dir ];then
    cd $dir
    echo "创建客户端证书请求文件(输入对应的账户名)"
    ./easyrsa gen-req $user nopass
    [ $? -eq 0 ] && echo "客户端证书请求文件创建成功！" || echo "客户端证书请求文件创建失败！"
    
    echo "创建客户证书(确认 并 输入证书密码)"
    ./easyrsa sign client $user
    [ $? -eq 0 ] && echo "客户端证书创建成功！" || echo "客户端证书创建失败！"
    cp $dir/pki/issued/${user}.crt ${ca_dir}/$user
    cp $dir/pki/private/${user}.key  ${ca_dir}/$user
    cp $dir/pki/ca.crt ${ca_dir}/$user
    cp $dir/ta.key ${ca_dir}/$user
  fi
}
function modify_user_file(){
  echo "$user  $pass" >> ${user_file}
  echo "结果如下："
  tail -1 ${user_file}
}
function client_cfg(){
cat > ${ca_dir}/$user/plus.ovpn <<EOF
client
proto udp
dev tun
auth-user-pass
remote ${vpn_server_ip} ${port}
route 192.168.1.0 255.255.255.0 vpn_gateway
ca ca.crt
tls-auth ta.key 1
cert ${user}.crt
key ${user}.key
remote-cert-tls server
data-ciphers AES-256-CBC
data-ciphers-fallback AES-256-CBC
auth-nocache
persist-tun
persist-key
reneg-sec 0
compress lzo
verb 3
mute 10
comp-lzo yes
allow-compression yes
EOF
cat >${ca_dir}/$user/readme.txt <<EOF
1. VPN账号: ${user},  密码是: ${pass}
2. 将除 readme 文件外的其他文件，全部存放至openvpn客户端的config目录下即可
3. 打开openvpn客户端，点击连接，使用上面账号和密码登录连接即可
EOF
# 打包文件
cd ${ca_dir}
zip -rq ${user}.zip ${user} &>/dev/null
}
function send_email(){
  read -p '请输入您的邮箱地址：' email
  echo 'VPN账号相关信息在附件中，请详细阅读 readme 文档' | mail -a ${ca_dir}/${user}.zip -s 'VPN账号信息' ${email}
  [ $? -eq 0 ] && echo "邮件已发送成功!" || echo "邮件发送失败!"
}
function main(){
  # 检测 参数是否正确
  Usage
  # 检查用户是否已经存在
  user_is_exist
  # 创建证书
  create_ca
  # 修改账号文件
  modify_user_file
  # 生成客户端配置文件
  client_cfg
}
main
# 脚本使用注意：需要传参
# bash /server/scripts/create_vpn_user.sh 账号 口令
