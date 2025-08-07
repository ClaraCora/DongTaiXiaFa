#!/bin/bash

# 动态家宽下发IP给被控端 - 智能一键安装脚本 (已修正)
# 作者: ClaraCora
# 项目地址: https://github.com/ClaraCora/DongTaiXiaFa
# 版本: 1.1

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
UNINSTALL_TARGET=""

# 默认参数
DEFAULT_INSTALL_TYPE="slave"
DEFAULT_SERVICE_INSTALL="yes"
DEFAULT_SLAVE_IP="127.0.0.1"
DEFAULT_SLAVE_PORT="5000"
DEFAULT_CHECK_INTERVAL="300"
DEFAULT_DNS_PATH="/etc/XrayR/dns.json"
DEFAULT_LISTEN_PORT="5000"
DEFAULT_AUTO_BACKUP="false"
DEFAULT_SECRET_KEY=""

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-type)
                INSTALL_TYPE="$2"; shift 2 ;;
            --service-install)
                SERVICE_INSTALL="$2"; shift 2 ;;
            --slave-ip)
                SLAVE_IP="$2"; shift 2 ;;
            --slave-port)
                SLAVE_PORT="$2"; shift 2 ;;
            --check-interval)
                CHECK_INTERVAL="$2"; shift 2 ;;
            --dns-path)
                DNS_PATH="$2"; shift 2 ;;
            --listen-port)
                LISTEN_PORT="$2"; shift 2 ;;
            --auto-backup)
                AUTO_BACKUP="$2"; shift 2 ;;
            --secret-key)
                SECRET_KEY="$2"; shift 2 ;;
            --uninstall)
                UNINSTALL_TARGET="$2"; shift 2 ;;
            --help|-h)
                show_help; exit 0 ;;
            *)
                echo "未知参数: $1"; show_help; exit 1 ;;
        esac
    done
}

# --- 卸载函数 (保持不变) ---
uninstall_master() {
    print_info "卸载主控端..."
    systemctl stop ip-monitor-master 2>/dev/null || true
    systemctl disable ip-monitor-master 2>/dev/null || true
    rm -f /etc/systemd/system/ip-monitor-master.service
    rm -rf /opt/ip_monitor_master
    systemctl daemon-reload
    print_success "主控端已卸载"
}
uninstall_slave() {
    print_info "卸载被控端..."
    systemctl stop ip-monitor-slave 2>/dev/null || true
    systemctl disable ip-monitor-slave 2>/dev/null || true
    rm -f /etc/systemd/system/ip-monitor-slave.service
    rm -rf /opt/ip_monitor_slave
    systemctl daemon-reload
    print_success "被控端已卸载"
}
handle_uninstall() {
    case "$UNINSTALL_TARGET" in
        master) uninstall_master ;;
        slave) uninstall_slave ;;
        both) uninstall_master; uninstall_slave ;;
        *) print_error "--uninstall 仅支持 master、slave、both"; exit 1 ;;
    esac
    exit 0
}

# --- 帮助和输出函数 (保持不变) ---
show_help() {
    echo "动态家宽下发IP给被控端 - 智能一键安装脚本"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --install-type TYPE     安装类型 (master|slave|both) [默认: slave]"
    echo "  --service-install YES   是否安装服务 (yes|no) [默认: yes]"
    echo "  --slave-ip IP           被控端IP地址 [默认: 127.0.0.1]"
    echo "  --slave-port PORT       被控端端口 [默认: 5000]"
    echo "  --check-interval SEC    检测间隔(秒) [默认: 300]"
    echo "  --dns-path PATH         DNS文件路径 [默认: /etc/XrayR/dns.json]"
    echo "  --listen-port PORT      监听端口 [默认: 5000]"
    echo "  --auto-backup YES       是否自动备份 (yes|no) [默认: no]"
    echo "  --secret-key KEY        通信密钥 [默认: 自动生成]"
    echo "  --uninstall TARGET      卸载 master、slave 或 both"
    echo "  --help, -h              显示此帮助信息"
}
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# --- 系统检查和下载函数 (保持不变) ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"; exit 1;
    fi
}
check_system() {
    print_info "检查系统要求..."
    if [[ -f /etc/os-release ]]; then . /etc/os-release; print_info "检测到操作系统: $PRETTY_NAME"; fi
    if ! ping -c 1 8.8.8.8 &> /dev/null; then print_error "网络连接失败"; exit 1; fi
    for tool in "git" "curl" "openssl"; do
        if ! command -v "$tool" &> /dev/null; then print_error "缺少必要工具: $tool"; exit 1; fi
    done
    print_success "系统要求检查通过"
}
download_project() {
    print_info "下载项目文件..."
    rm -rf "$TEMP_DIR"; mkdir -p "$TEMP_DIR"; cd "$TEMP_DIR"
    if git clone "$REPO_URL" .; then
        print_success "项目文件下载完成"
    else
        print_error "项目文件下载失败"; exit 1
    fi
}

# 生成随机密钥
generate_secret_key() {
    openssl rand -hex 32
}

# 交互式配置主控端
configure_master() {
    print_header "配置主控端"
    
    local secret_key=$(generate_secret_key)
    local slave_ip=""
    local slave_port=""
    local check_interval=""
    
    # --- 修正点 1：将 elif 改为独立的 if ---
    if [ -n "$SLAVE_IP" ]; then
        slave_ip="$SLAVE_IP"
        print_info "使用命令行参数: 被控端IP = $slave_ip"
    fi
    if [ -n "$SLAVE_PORT" ]; then
        slave_port="$SLAVE_PORT"
        print_info "使用命令行参数: 被控端端口 = $slave_port"
    fi
    if [ -n "$CHECK_INTERVAL" ]; then
        check_interval="$CHECK_INTERVAL"
        print_info "使用命令行参数: 检测间隔 = $check_interval"
    fi
    
    if [ -t 0 ] && [ -z "$SLAVE_IP" ]; then # 仅在非交互式未提供IP时才询问
        read -p "请输入被控端IP地址: " slave_ip
        read -p "请输入被控端端口 (默认: ${DEFAULT_SLAVE_PORT}): " slave_port
        read -p "请输入IP检测间隔(秒, 默认: ${DEFAULT_CHECK_INTERVAL}): " check_interval
    fi
    
    # 应用默认值
    slave_ip=${slave_ip:-$DEFAULT_SLAVE_IP}
    slave_port=${slave_port:-$DEFAULT_SLAVE_PORT}
    check_interval=${check_interval:-$DEFAULT_CHECK_INTERVAL}
    
    MASTER_CONFIG="[DEFAULT]
check_interval = $check_interval
ip_record_file = /opt/ip_monitor_master/current_ip.txt
slave_api_urls = http://$slave_ip:$slave_port/update_dns
secret_key = $secret_key"
    
    print_success "主控端配置完成"
    echo; print_info "=== 重要信息 ==="
    print_info "通信密钥: $secret_key"
    print_info "请记录此密钥，被控端需要使用相同的密钥"
    print_info "=================="
}

# 交互式配置被控端
configure_slave() {
    print_header "配置被控端"
    
    local secret_key=""
    local dns_path=""
    local listen_port=""
    local auto_backup=""

    # --- 修正点 1：将 elif 改为独立的 if ---
    if [ -n "$SECRET_KEY" ]; then
        secret_key="$SECRET_KEY"
        print_info "使用命令行参数: 通信密钥已提供"
    fi
    if [ -n "$DNS_PATH" ]; then
        dns_path="$DNS_PATH"
        print_info "使用命令行参数: DNS路径 = $dns_path"
    fi
    if [ -n "$LISTEN_PORT" ]; then
        listen_port="$LISTEN_PORT"
        print_info "使用命令行参数: 监听端口 = $listen_port"
    fi
    if [ -n "$AUTO_BACKUP" ]; then
        auto_backup="$AUTO_BACKUP"
        print_info "使用命令行参数: 自动备份 = $auto_backup"
    fi

    if [ -t 0 ] && [ -z "$SECRET_KEY" ]; then # 仅在非交互式未提供密钥时才询问
        read -p "请输入与主控端相同的通信密钥: " secret_key
        read -p "请输入XrayR的dns.json文件路径 (默认: ${DEFAULT_DNS_PATH}): " dns_path
        read -p "请输入监听端口 (默认: ${DEFAULT_LISTEN_PORT}): " listen_port
        read -p "是否启用自动备份 (yes/no, 默认: no): " auto_backup
    fi
    
    # 应用默认值
    if [ -z "$secret_key" ]; then
        print_warning "未提供密钥，将生成新的随机密钥"
        secret_key=$(generate_secret_key)
    fi
    dns_path=${dns_path:-$DEFAULT_DNS_PATH}
    listen_port=${listen_port:-$DEFAULT_LISTEN_PORT}
    auto_backup_input=${auto_backup:-$DEFAULT_AUTO_BACKUP}
    
    if [[ "$auto_backup_input" == "y" || "$auto_backup_input" == "Y" || "$auto_backup_input" == "yes" ]]; then
        auto_backup_val="true"
    else
        auto_backup_val="false"
    fi
    
    SLAVE_CONFIG="[DEFAULT]
listen_host = 0.0.0.0
listen_port = $listen_port
dns_file_path = $dns_path
secret_key = $secret_key
auto_backup = $auto_backup_val
restart_service = true
restart_command = xrayr restart"
    
    print_success "被控端配置完成"
    print_info "通信密钥: $secret_key"
}

# 安装主控端
install_master() {
    print_info "安装主控端..."
    mkdir -p /opt/ip_monitor_master
    
    # --- 修正点 2：使用更安全的文件复制方式 ---
    if [ -d "$TEMP_DIR/master" ]; then
        cp -a "$TEMP_DIR/master/." /opt/ip_monitor_master/
        chmod +x /opt/ip_monitor_master/master
    else
        print_error "安装失败: 找不到源文件目录 $TEMP_DIR/master"; exit 1
    fi
    
    echo "$MASTER_CONFIG" > /opt/ip_monitor_master/master_config.ini
    
    cat > /etc/systemd/system/ip-monitor-master.service << EOF
[Unit]
Description=IP Monitor Master Service
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
    mkdir -p /opt/ip_monitor_slave
    
    # --- 修正点 2：使用更安全的文件复制方式 ---
    if [ -d "$TEMP_DIR/slave" ]; then
        cp -a "$TEMP_DIR/slave/." /opt/ip_monitor_slave/
        chmod +x /opt/ip_monitor_slave/slave
    else
        print_error "安装失败: 找不到源文件目录 $TEMP_DIR/slave"; exit 1
    fi
    
    echo "$SLAVE_CONFIG" > /opt/ip_monitor_slave/slave_config.ini
    
    cat > /etc/systemd/system/ip-monitor-slave.service << EOF
[Unit]
Description=IP Monitor Slave Service
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

# --- 防火墙、服务启动、结果显示、清理函数 (保持不变) ---
configure_firewall() {
    print_info "检查防火墙状态..."
    if command -v ufw &> /dev/null; then
        print_warning "检测到UFW防火墙，请手动开放端口: sudo ufw allow ${listen_port:-$DEFAULT_LISTEN_PORT}/tcp"
    elif command -v firewall-cmd &> /dev/null; then
        print_warning "检测到firewalld防火墙，请手动开放端口: sudo firewall-cmd --permanent --add-port=${listen_port:-$DEFAULT_LISTEN_PORT}/tcp && sudo firewall-cmd --reload"
    fi
}
start_services() {
    print_info "启动服务..."
    systemctl daemon-reload
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        systemctl enable ip-monitor-master; systemctl start ip-monitor-master
        print_success "主控端服务已启动"
    fi
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        systemctl enable ip-monitor-slave; systemctl start ip-monitor-slave
        print_success "被控端服务已启动"
    fi
}
show_install_result() {
    print_header "安装完成"
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        echo; print_info "主控端信息:"
        echo "- 安装路径: /opt/ip_monitor_master"
        echo "- 配置文件: /opt/ip_monitor_master/master_config.ini"
        echo "- 服务名称: ip-monitor-master"
        echo "- 通信密钥: $(grep '^secret_key =' /opt/ip_monitor_master/master_config.ini | cut -d'=' -f2 | tr -d ' ')"
    fi
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        echo; print_info "被控端信息:"
        echo "- 安装路径: /opt/ip_monitor_slave"
        echo "- 配置文件: /opt/ip_monitor_slave/slave_config.ini"
        echo "- 服务名称: ip-monitor-slave"
        echo "- 通信密钥: $(grep '^secret_key =' /opt/ip_monitor_slave/slave_config.ini | cut -d'=' -f2 | tr -d ' ')"
    fi
    echo; print_info "常用命令:"
    echo "- 查看服务状态: systemctl status ip-monitor-master"
    echo "- 查看日志: journalctl -u ip-monitor-master -f"
}
cleanup() {
    print_info "清理临时文件..."; rm -rf "$TEMP_DIR"; print_success "清理完成";
}

# 交互式选择安装类型
select_install_type() {
    print_header "选择安装类型"
    echo "1) 主控端 (master)"; echo "2) 被控端 (slave)"; echo "3) 全部 (both)"; echo "4) 退出"
    if [ -t 0 ]; then read -p "请输入选择 (1-4): " choice; else choice=2; fi
    case $choice in
        1) INSTALL_TYPE="master" ;; 2) INSTALL_TYPE="slave" ;;
        3) INSTALL_TYPE="both" ;; 4) print_info "安装已取消"; exit 0 ;;
        *) print_error "无效选择"; exit 1 ;;
    esac
}
ask_service_install() {
    echo; print_info "是否安装systemd服务并设置开机自启？"
    echo "1) 是"; echo "2) 否"
    if [ -t 0 ]; then read -p "请输入选择 (1-2): " choice; else choice=1; fi
    case $choice in
        1) SERVICE_INSTALL="yes" ;; 2) SERVICE_INSTALL="no" ;;
        *) print_error "无效选择"; exit 1 ;;
    esac
}

# 主函数
main() {
    print_header "动态家宽下发IP给被控端 - 智能一键安装"
    check_root
    check_system
    parse_args "$@"

    if [ -n "$UNINSTALL_TARGET" ]; then
        handle_uninstall
    fi

    if [ -z "$INSTALL_TYPE" ]; then
        select_install_type
    fi
    if [ -z "$SERVICE_INSTALL" ]; then
        ask_service_install
    fi
    
    download_project
    
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        configure_master
    fi
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        configure_slave
    fi
    
    if [[ "$INSTALL_TYPE" == "master" || "$INSTALL_TYPE" == "both" ]]; then
        install_master
    fi
    if [[ "$INSTALL_TYPE" == "slave" || "$INSTALL_TYPE" == "both" ]]; then
        install_slave
        configure_firewall
    fi
    
    if [[ "$SERVICE_INSTALL" == "yes" ]]; then
        start_services
    fi
    
    show_install_result
    cleanup
}

# 运行主函数
main "$@"
