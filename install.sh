#!/bin/bash

# 动态家宽下发IP给被控端 - 一键安装脚本
# 作者: ClaraCora
# 项目地址: https://github.com/ClaraCora/DongTaiXiaFa

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    print_info "检查系统要求..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        print_info "检测到操作系统: $PRETTY_NAME"
    else
        print_warning "无法检测操作系统类型"
    fi
    
    # 检查网络连接
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        print_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    
    print_success "系统要求检查通过"
}

# 生成随机密钥
generate_secret_key() {
    openssl rand -hex 32
}

# 安装主控端
install_master() {
    print_info "开始安装主控端..."
    
    # 创建目录
    mkdir -p /opt/ip_monitor_master
    cd /opt/ip_monitor_master
    
    # 复制文件
    cp -r "$SCRIPT_DIR/master/"* .
    chmod +x master start.sh
    
    # 生成配置
    SECRET_KEY=$(generate_secret_key)
    
    cat > master_config.ini << EOF
[DEFAULT]
# 检测时间间隔（秒）
check_interval = 300

# IP 记录文件路径
ip_record_file = /opt/ip_monitor_master/current_ip.txt

# 被控端 API 地址列表（用逗号分隔）
# 请根据实际情况修改被控端地址
slave_api_urls = http://192.168.1.100:5000/update_dns

# 通讯密钥
secret_key = $SECRET_KEY

# 日志级别
log_level = INFO

# 日志文件路径
log_file = /opt/ip_monitor_master/master.log

# 网络超时设置（秒）
timeout = 15

# 重试次数
retry_count = 3

# 重试间隔（秒）
retry_interval = 5
EOF
    
    # 创建systemd服务
    cat > /etc/systemd/system/ip-monitor-master.service << EOF
[Unit]
Description=IP Monitor Master
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ip_monitor_master
ExecStart=/opt/ip_monitor_master/master
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    print_success "主控端安装完成"
    print_info "配置文件位置: /opt/ip_monitor_master/master_config.ini"
    print_info "通信密钥: $SECRET_KEY"
    print_info "请修改配置文件中的被控端地址"
}

# 安装被控端
install_slave() {
    print_info "开始安装被控端..."
    
    # 创建目录
    mkdir -p /opt/ip_monitor_slave
    cd /opt/ip_monitor_slave
    
    # 复制文件
    cp -r "$SCRIPT_DIR/slave/"* .
    chmod +x slave start.sh
    
    # 生成配置
    SECRET_KEY=$(generate_secret_key)
    
    cat > slave_config.ini << EOF
[DEFAULT]
# 监听的 IP 地址
listen_host = 0.0.0.0

# 监听的端口
listen_port = 5000

# XrayR 的 dns.json 文件路径
# 请根据实际XrayR安装路径修改
dns_file_path = /etc/XrayR/dns.json

# 通讯密钥
secret_key = $SECRET_KEY

# 日志级别
log_level = INFO

# 日志文件路径
log_file = /opt/ip_monitor_slave/slave.log

# 自动备份设置
auto_backup = true

# 备份文件保留数量
backup_retention = 10

# 文件权限设置
file_permission = 644
dir_permission = 755
EOF
    
    # 创建systemd服务
    cat > /etc/systemd/system/ip-monitor-slave.service << EOF
[Unit]
Description=IP Monitor Slave
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ip_monitor_slave
ExecStart=/opt/ip_monitor_slave/slave
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    print_success "被控端安装完成"
    print_info "配置文件位置: /opt/ip_monitor_slave/slave_config.ini"
    print_info "通信密钥: $SECRET_KEY"
    print_info "请修改配置文件中的DNS文件路径"
}

# 配置防火墙
configure_firewall() {
    print_info "检查防火墙状态..."
    
    # 检测防火墙类型并提示用户
    if command -v ufw &> /dev/null; then
        print_warning "检测到UFW防火墙，请手动开放端口: sudo ufw allow 5000/tcp"
    elif command -v firewall-cmd &> /dev/null; then
        print_warning "检测到firewalld防火墙，请手动开放端口: sudo firewall-cmd --permanent --add-port=5000/tcp && sudo firewall-cmd --reload"
    elif command -v iptables &> /dev/null; then
        print_warning "检测到iptables防火墙，请手动开放端口: sudo iptables -A INPUT -p tcp --dport 5000 -j ACCEPT"
    else
        print_info "未检测到防火墙，端口5000应该可以直接访问"
    fi
    
    print_info "如果无法连接被控端，请检查防火墙设置"
}

# 启动服务
start_services() {
    print_info "启动服务..."
    
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        systemctl enable ip-monitor-master
        systemctl start ip-monitor-master
        print_success "主控端服务已启动"
    fi
    
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        systemctl enable ip-monitor-slave
        systemctl start ip-monitor-slave
        print_success "被控端服务已启动"
    fi
}

# 显示状态
show_status() {
    print_info "服务状态:"
    
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        systemctl status ip-monitor-master --no-pager -l
    fi
    
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        systemctl status ip-monitor-slave --no-pager -l
    fi
}

# 显示使用说明
show_usage() {
    print_info "安装完成！"
    echo
    print_info "使用说明:"
    echo "1. 查看服务状态: systemctl status ip-monitor-master ip-monitor-slave"
    echo "2. 查看日志: journalctl -u ip-monitor-master -f"
    echo "3. 停止服务: systemctl stop ip-monitor-master ip-monitor-slave"
    echo "4. 重启服务: systemctl restart ip-monitor-master ip-monitor-slave"
    echo
    print_info "配置文件位置:"
    echo "- 主控端: /opt/ip_monitor_master/master_config.ini"
    echo "- 被控端: /opt/ip_monitor_slave/slave_config.ini"
    echo
    print_info "请根据实际情况修改配置文件中的地址和路径"
    echo
    print_info "更多信息请查看: https://github.com/ClaraCora/DongTaiXiaFa"
}

# 主函数
main() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    print_info "动态家宽下发IP给被控端 - 一键安装脚本"
    print_info "项目地址: https://github.com/ClaraCora/DongTaiXiaFa"
    echo
    
    # 检查参数
    if [[ $# -eq 0 ]]; then
        echo "请选择安装类型:"
        echo "1) 主控端 (master)"
        echo "2) 被控端 (slave)"
        echo "3) 全部 (both)"
        echo "4) 退出"
        read -p "请输入选择 (1-4): " choice
        
        case $choice in
            1) INSTALL_TYPE="master" ;;
            2) INSTALL_TYPE="slave" ;;
            3) INSTALL_TYPE="both" ;;
            4) exit 0 ;;
            *) print_error "无效选择"; exit 1 ;;
        esac
    else
        INSTALL_TYPE="$1"
    fi
    
    # 验证安装类型
    if [[ "$INSTALL_TYPE" != "master" && "$INSTALL_TYPE" != "slave" && "$INSTALL_TYPE" != "both" ]]; then
        print_error "无效的安装类型: $INSTALL_TYPE"
        print_info "可用选项: master, slave, both"
        exit 1
    fi
    
    # 检查root权限
    check_root
    
    # 检查系统要求
    check_system
    
    # 安装组件
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        install_master
    fi
    
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        install_slave
        configure_firewall
    fi
    
    # 启动服务
    start_services
    
    # 显示状态
    show_status
    
    # 显示使用说明
    show_usage
}

# 运行主函数
main "$@" 