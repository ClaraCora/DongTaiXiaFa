#!/bin/bash

# 动态家宽下发IP给被控端 - 卸载脚本
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

# 停止服务
stop_services() {
    print_info "停止服务..."
    
    # 停止主控端服务
    if systemctl is-active --quiet ip-monitor-master; then
        systemctl stop ip-monitor-master
        print_success "主控端服务已停止"
    fi
    
    # 停止被控端服务
    if systemctl is-active --quiet ip-monitor-slave; then
        systemctl stop ip-monitor-slave
        print_success "被控端服务已停止"
    fi
}

# 禁用服务
disable_services() {
    print_info "禁用服务..."
    
    # 禁用主控端服务
    if systemctl is-enabled --quiet ip-monitor-master; then
        systemctl disable ip-monitor-master
        print_success "主控端服务已禁用"
    fi
    
    # 禁用被控端服务
    if systemctl is-enabled --quiet ip-monitor-slave; then
        systemctl disable ip-monitor-slave
        print_success "被控端服务已禁用"
    fi
}

# 删除服务文件
remove_service_files() {
    print_info "删除服务文件..."
    
    # 删除主控端服务文件
    if [[ -f /etc/systemd/system/ip-monitor-master.service ]]; then
        rm -f /etc/systemd/system/ip-monitor-master.service
        print_success "主控端服务文件已删除"
    fi
    
    # 删除被控端服务文件
    if [[ -f /etc/systemd/system/ip-monitor-slave.service ]]; then
        rm -f /etc/systemd/system/ip-monitor-slave.service
        print_success "被控端服务文件已删除"
    fi
    
    # 重新加载systemd
    systemctl daemon-reload
    print_success "systemd已重新加载"
}

# 删除安装目录
remove_install_dirs() {
    print_info "删除安装目录..."
    
    # 删除主控端目录
    if [[ -d /opt/ip_monitor_master ]]; then
        rm -rf /opt/ip_monitor_master
        print_success "主控端目录已删除"
    fi
    
    # 删除被控端目录
    if [[ -d /opt/ip_monitor_slave ]]; then
        rm -rf /opt/ip_monitor_slave
        print_success "被控端目录已删除"
    fi
}

# 清理防火墙规则
cleanup_firewall() {
    print_info "检查防火墙规则..."
    
    # 检测防火墙类型并提示用户
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "5000/tcp"; then
            print_warning "检测到UFW防火墙规则，请手动清理: sudo ufw delete allow 5000/tcp"
        else
            print_info "UFW防火墙中未发现5000端口规则"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --list-ports | grep -q "5000/tcp"; then
            print_warning "检测到firewalld防火墙规则，请手动清理: sudo firewall-cmd --permanent --remove-port=5000/tcp && sudo firewall-cmd --reload"
        else
            print_info "firewalld防火墙中未发现5000端口规则"
        fi
    elif command -v iptables &> /dev/null; then
        if iptables -L INPUT | grep -q "5000"; then
            print_warning "检测到iptables防火墙规则，请手动清理: sudo iptables -D INPUT -p tcp --dport 5000 -j ACCEPT"
        else
            print_info "iptables防火墙中未发现5000端口规则"
        fi
    else
        print_info "未检测到防火墙，无需清理防火墙规则"
    fi
}

# 清理日志文件
cleanup_logs() {
    print_info "清理日志文件..."
    
    # 清理systemd日志
    journalctl --vacuum-time=1s --unit=ip-monitor-master 2>/dev/null || true
    journalctl --vacuum-time=1s --unit=ip-monitor-slave 2>/dev/null || true
    
    print_success "日志文件已清理"
}

# 显示卸载信息
show_uninstall_info() {
    print_info "卸载完成！"
    echo
    print_info "已清理的内容:"
    echo "- 停止并禁用了所有相关服务"
    echo "- 删除了systemd服务文件"
    echo "- 删除了安装目录和文件"
    echo "- 清理了防火墙规则"
    echo "- 清理了相关日志"
    echo
    print_info "如果还有其他相关文件需要清理，请手动删除"
}

# 确认卸载
confirm_uninstall() {
    echo
    print_warning "此操作将完全删除动态家宽下发IP工具的所有文件和服务"
    print_warning "包括:"
    echo "- 所有配置文件"
    echo "- 所有日志文件"
    echo "- 所有服务文件"
    echo "- 所有安装目录"
    echo
    read -p "确定要继续卸载吗？(y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "卸载已取消"
        exit 0
    fi
}

# 主函数
main() {
    print_info "动态家宽下发IP给被控端 - 卸载脚本"
    print_info "项目地址: https://github.com/ClaraCora/DongTaiXiaFa"
    echo
    
    # 检查root权限
    check_root
    
    # 确认卸载
    confirm_uninstall
    
    # 执行卸载步骤
    stop_services
    disable_services
    remove_service_files
    remove_install_dirs
    cleanup_firewall
    cleanup_logs
    
    # 显示卸载信息
    show_uninstall_info
}

# 运行主函数
main "$@" 