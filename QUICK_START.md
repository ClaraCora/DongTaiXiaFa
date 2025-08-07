# 快速开始指南

## 🚀 一键安装

### 方法一：智能一键安装（最推荐）

```bash
# 方式一：bash开头的一键命令
bash <(curl -sSL https://raw.githubusercontent.com/ClaraCora/DongTaiXiaFa/main/auto_install.sh)

# 方式二：直接运行
curl -sSL https://raw.githubusercontent.com/ClaraCora/DongTaiXiaFa/main/auto_install.sh | sudo bash
```

或者：

```bash
# 克隆项目后运行智能安装脚本
git clone https://github.com/ClaraCora/DongTaiXiaFa.git
cd DongTaiXiaFa
sudo ./auto_install.sh
```

智能安装脚本特点：
- 🔄 自动下载最新版本
- ⚙️ 交互式配置（IP地址、端口、密钥等）
- 🛠️ 自动生成配置文件
- 🔧 可选安装systemd服务
- 🛡️ 检查防火墙状态并提示
- 📊 显示安装结果和常用命令

### 方法二：使用基础安装脚本

```bash
# 下载项目
git clone https://github.com/ClaraCora/DongTaiXiaFa.git
cd DongTaiXiaFa

# 运行安装脚本
sudo ./install.sh
```

安装脚本会引导你选择安装类型：
- `master`: 只安装主控端
- `slave`: 只安装被控端  
- `both`: 安装主控端和被控端

### 方法二：手动安装

```bash
# 1. 安装主控端
sudo mkdir -p /opt/ip_monitor_master
sudo cp master/* /opt/ip_monitor_master/
sudo chmod +x /opt/ip_monitor_master/master
sudo chmod +x /opt/ip_monitor_master/start.sh

# 2. 安装被控端
sudo mkdir -p /opt/ip_monitor_slave
sudo cp slave/* /opt/ip_monitor_slave/
sudo chmod +x /opt/ip_monitor_slave/slave
sudo chmod +x /opt/ip_monitor_slave/start.sh
```

## ⚙️ 快速配置

### 主控端配置

编辑 `/opt/ip_monitor_master/master_config.ini`：

```ini
[DEFAULT]
# 被控端地址（修改为你的被控端IP）
slave_api_urls = http://你的被控端IP:5000/update_dns

# 通信密钥（必须与被控端相同）
secret_key = your_secret_key_here

# 检测间隔（秒）
check_interval = 300
```

### 被控端配置

编辑 `/opt/ip_monitor_slave/slave_config.ini`：

```ini
[DEFAULT]
# XrayR的dns.json文件路径
dns_file_path = /etc/XrayR/dns.json

# 通信密钥（必须与主控端相同）
secret_key = your_secret_key_here

# 监听端口
listen_port = 5000
```

## 🎯 启动服务

```bash
# 启动主控端
sudo systemctl start ip-monitor-master
sudo systemctl enable ip-monitor-master

# 启动被控端
sudo systemctl start ip-monitor-slave
sudo systemctl enable ip-monitor-slave
```

## 📊 检查状态

```bash
# 查看服务状态
sudo systemctl status ip-monitor-master
sudo systemctl status ip-monitor-slave

# 查看日志
sudo journalctl -u ip-monitor-master -f
sudo journalctl -u ip-monitor-slave -f
```

## 🔧 常用命令

```bash
# 重启服务
sudo systemctl restart ip-monitor-master
sudo systemctl restart ip-monitor-slave

# 停止服务
sudo systemctl stop ip-monitor-master
sudo systemctl stop ip-monitor-slave

# 查看配置文件
sudo cat /opt/ip_monitor_master/master_config.ini
sudo cat /opt/ip_monitor_slave/slave_config.ini
```

## 🗑️ 卸载

```bash
# 运行卸载脚本
sudo ./uninstall.sh
```

## ❓ 常见问题

### Q: 主控端无法连接被控端
A: 检查以下几点：
- 被控端IP地址是否正确
- 防火墙是否开放5000端口（大多数VPS默认无防火墙）
- 被控端服务是否正常运行

### Q: 被控端无法更新DNS文件
A: 检查以下几点：
- DNS文件路径是否正确
- 文件权限是否足够
- XrayR是否已安装

### Q: 服务启动失败
A: 检查以下几点：
- 配置文件语法是否正确
- 二进制文件是否有执行权限
- 查看系统日志获取详细错误信息

## 📞 获取帮助

- 📖 完整文档：[README.md](README.md)
- 🐛 问题反馈：[GitHub Issues](https://github.com/ClaraCora/DongTaiXiaFa/issues)
- 📧 项目地址：[https://github.com/ClaraCora/DongTaiXiaFa](https://github.com/ClaraCora/DongTaiXiaFa) 