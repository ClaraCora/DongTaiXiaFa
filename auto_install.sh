#!/bin/bash

# 动态家宽下发IP给被控端 - 智能一键安装脚本
# 作者: ClaraCora
# 项目地址: https://github.com/ClaraCora/DongTaiXiaFa

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/ClaraCora/DongTaiXiaFa.git"
TEMP_DIR="/tmp/dongtaixiafa_install"
INSTALL_TYPE=""
MASTER_CONFIG=""
SLAVE_CONFIG=""
SERVICE_INSTALL=""

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

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
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
    
    # 检查必要的工具
    local required_tools=("git" "curl" "openssl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "缺少必要工具: $tool"
            print_info "请安装: $tool"
            exit 1
        fi
    done
    
    print_success "系统要求检查通过"
}

# 下载项目文件
download_project() {
    print_info "下载项目文件..."
    
    # 创建临时目录
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # 克隆项目
    if git clone "$REPO_URL" .; then
        print_success "项目文件下载完成"
    else
        print_error "项目文件下载失败"
        exit 1
    fi
}

# 生成随机密钥
generate_secret_key() {
    openssl rand -hex 32
}

# 交互式配置主控端
configure_master() {
    print_header "配置主控端"
    
    # 生成随机密钥
    local secret_key=$(generate_secret_key)
    
    # 获取被控端地址
    echo
    print_info "请输入被控端信息:"
    read -p "被控端IP地址: " slave_ip
    read -p "被控端端口 (默认5000): " slave_port
    slave_port=${slave_port:-5000}
    
    # 获取检测间隔
    read -p "IP检测间隔(秒，默认300): " check_interval
    check_interval=${check_interval:-300}
    
    # 生成主控端配置
    MASTER_CONFIG="[DEFAULT]
# 检测时间间隔（秒）
check_interval = $check_interval

# IP 记录文件路径
ip_record_file = /opt/ip_monitor_master/current_ip.txt

# 被控端 API 地址列表（用逗号分隔）
slave_api_urls = http://$slave_ip:$slave_port/update_dns

# 通讯密钥
secret_key = $secret_key

# 日志级别
log_level = INFO

# 日志文件路径
log_file = /opt/ip_monitor_master/master.log

# 网络超时设置（秒）
timeout = 15

# 重试次数
retry_count = 3

# 重试间隔（秒）
retry_interval = 5"
    
    print_success "主控端配置完成"
    print_info "通信密钥: $secret_key"
}

# 交互式配置被控端
configure_slave() {
    print_header "配置被控端"
    
    # 生成随机密钥
    local secret_key=$(generate_secret_key)
    
    # 获取DNS文件路径
    echo
    print_info "请输入DNS配置信息:"
    read -p "XrayR的dns.json文件路径 (默认/etc/XrayR/dns.json): " dns_path
    dns_path=${dns_path:-/etc/XrayR/dns.json}
    
    # 获取监听端口
    read -p "监听端口 (默认5000): " listen_port
    listen_port=${listen_port:-5000}
    
    # 获取备份设置
    read -p "是否启用自动备份 (y/N): " auto_backup
    auto_backup=${auto_backup:-false}
    if [[ "$auto_backup" == "y" || "$auto_backup" == "Y" ]]; then
        auto_backup="true"
    else
        auto_backup="false"
    fi
    
    # 生成被控端配置
    SLAVE_CONFIG="[DEFAULT]
# 监听的 IP 地址
listen_host = 0.0.0.0

# 监听的端口
listen_port = $listen_port

# XrayR 的 dns.json 文件路径
dns_file_path = $dns_path

# 通讯密钥
secret_key = $secret_key

# 日志级别
log_level = INFO

# 日志文件路径
log_file = /opt/ip_monitor_slave/slave.log

# 自动备份设置
auto_backup = $auto_backup

# 备份文件保留数量
backup_retention = 10

# 文件权限设置
file_permission = 644
dir_permission = 755"
    
    print_success "被控端配置完成"
    print_info "通信密钥: $secret_key"
}

# 安装主控端
install_master() {
    print_info "安装主控端..."
    
    # 创建目录
    mkdir -p /opt/ip_monitor_master
    cd /opt/ip_monitor_master
    
    # 复制文件
    cp -r "$TEMP_DIR/master/"* .
    chmod +x master start.sh
    
    # 写入配置
    echo "$MASTER_CONFIG" > master_config.ini
    
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
    
    print_success "主控端安装完成"
}

# 安装被控端
install_slave() {
    print_info "安装被控端..."
    
    # 创建目录
    mkdir -p /opt/ip_monitor_slave
    cd /opt/ip_monitor_slave
    
    # 复制文件
    cp -r "$TEMP_DIR/slave/"* .
    chmod +x slave start.sh
    
    # 写入配置
    echo "$SLAVE_CONFIG" > slave_config.ini
    
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
    
    print_success "被控端安装完成"
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
    
    # 重新加载systemd
    systemctl daemon-reload
    
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

# 显示安装结果
show_install_result() {
    print_header "安装完成"
    
    echo
    print_info "安装信息:"
    echo "- 安装类型: $INSTALL_TYPE"
    echo "- 服务安装: $SERVICE_INSTALL"
    
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        echo
        print_info "主控端信息:"
        echo "- 安装路径: /opt/ip_monitor_master"
        echo "- 配置文件: /opt/ip_monitor_master/master_config.ini"
        echo "- 服务名称: ip-monitor-master"
    fi
    
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        echo
        print_info "被控端信息:"
        echo "- 安装路径: /opt/ip_monitor_slave"
        echo "- 配置文件: /opt/ip_monitor_slave/slave_config.ini"
        echo "- 服务名称: ip-monitor-slave"
    fi
    
    echo
    print_info "常用命令:"
    echo "- 查看服务状态: systemctl status ip-monitor-master ip-monitor-slave"
    echo "- 查看日志: journalctl -u ip-monitor-master -f"
    echo "- 重启服务: systemctl restart ip-monitor-master ip-monitor-slave"
    echo "- 停止服务: systemctl stop ip-monitor-master ip-monitor-slave"
    
    echo
    print_info "更多信息请查看: https://github.com/ClaraCora/DongTaiXiaFa"
}

# 交互式选择安装类型
select_install_type() {
    print_header "选择安装类型"
    
    echo "请选择要安装的组件:"
    echo "1) 主控端 (master) - 监控IP变化并通知被控端"
    echo "2) 被控端 (slave) - 接收IP更新并修改DNS配置"
    echo "3) 全部 (both) - 安装主控端和被控端"
    echo "4) 退出"
    
    read -p "请输入选择 (1-4): " choice
    
    case $choice in
        1) INSTALL_TYPE="master" ;;
        2) INSTALL_TYPE="slave" ;;
        3) INSTALL_TYPE="both" ;;
        4) 
            print_info "安装已取消"
            exit 0 
            ;;
        *) 
            print_error "无效选择"
            exit 1 
            ;;
    esac
}

# 询问是否安装服务
ask_service_install() {
    echo
    print_info "是否安装systemd服务并设置开机自启？"
    echo "1) 是 - 安装服务并设置开机自启"
    echo "2) 否 - 仅安装文件，手动启动"
    
    read -p "请输入选择 (1-2): " choice
    
    case $choice in
        1) SERVICE_INSTALL="yes" ;;
        2) SERVICE_INSTALL="no" ;;
        *) 
            print_error "无效选择"
            exit 1 
            ;;
    esac
}

# 清理临时文件
cleanup() {
    print_info "清理临时文件..."
    rm -rf "$TEMP_DIR"
    print_success "清理完成"
}

# 主函数
main() {
    print_header "动态家宽下发IP给被控端 - 智能一键安装"
    print_info "项目地址: $REPO_URL"
    echo
    
    # 检查root权限
    check_root
    
    # 检查系统要求
    check_system
    
    # 选择安装类型
    select_install_type
    
    # 询问服务安装
    ask_service_install
    
    # 下载项目文件
    download_project
    
    # 配置组件
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        configure_master
    fi
    
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        configure_slave
    fi
    
    # 安装组件
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        install_master
    fi
    
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        install_slave
        configure_firewall
    fi
    
    # 启动服务
    if [[ "$SERVICE_INSTALL" == "yes" ]]; then
        start_services
    fi
    
    # 显示安装结果
    show_install_result
    
    # 清理临时文件
    cleanup
}

# 运行主函数
main "$@" 