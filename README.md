# 动态家宽下发IP给被控端 - 部署包

## 项目简介

这是一个用于动态家宽IP地址监控和自动下发到被控端的工具。主控端会定期检测IP地址变化，当检测到IP变化时，自动通知被控端更新DNS配置文件。

## 功能特性

- 🔄 自动检测IP地址变化
- 📡 支持多个被控端同时更新
- 🔐 安全的通信密钥验证
- 📝 详细的日志记录
- 🔄 自动备份DNS配置文件
- ⚡ 快速响应IP变化

## 目录结构

```
final/
├── master/          # 主控端部署包
│   ├── master      # 主控端二进制文件
│   ├── master_config.ini  # 主控端配置文件
│   └── start.sh    # 启动脚本
└── slave/           # 被控端部署包
    ├── slave        # 被控端二进制文件
    ├── slave_config.ini  # 被控端配置文件
    └── start.sh     # 启动脚本
```

## 系统要求

- Linux 系统（推荐 Ubuntu 18.04+ 或 CentOS 7+）
- 网络连接正常
- 被控端需要安装 XrayR

## 快速开始

### 1. 下载部署包

```bash
# 克隆项目
git clone https://github.com/ClaraCora/DongTaiXiaFa.git
cd DongTaiXiaFa
```

### 2. 部署主控端

1. **上传文件到主控服务器**
   ```bash
   # 将 master/ 目录上传到主控服务器
   scp -r master/ user@your-master-server:/opt/ip_monitor_master/
   ```

2. **配置主控端**
   ```bash
   cd /opt/ip_monitor_master/
   nano master_config.ini
   ```

   主要配置项说明：
   - `check_interval`: 检测间隔（秒），建议300秒
   - `slave_api_urls`: 被控端API地址，多个用逗号分隔
   - `secret_key`: 通信密钥，必须与被控端相同
   - `log_level`: 日志级别（DEBUG/INFO/WARNING/ERROR）

3. **启动主控端**
   ```bash
   chmod +x start.sh
   ./start.sh
   ```

### 3. 部署被控端

1. **上传文件到被控服务器**
   ```bash
   # 将 slave/ 目录上传到被控服务器
   scp -r slave/ user@your-slave-server:/opt/ip_monitor_slave/
   ```

2. **配置被控端**
   ```bash
   cd /opt/ip_monitor_slave/
   nano slave_config.ini
   ```

   主要配置项说明：
   - `listen_host`: 监听地址（0.0.0.0表示所有接口）
   - `listen_port`: 监听端口（默认5000）
   - `dns_file_path`: XrayR的dns.json文件路径
   - `secret_key`: 通信密钥，必须与主控端相同
   - `auto_backup`: 是否自动备份DNS文件

3. **启动被控端**
   ```bash
   chmod +x start.sh
   ./start.sh
   ```

## 详细配置说明

### 主控端配置 (master_config.ini)

```ini
[DEFAULT]
# 检测时间间隔（秒）
check_interval = 300

# IP 记录文件路径
ip_record_file = /opt/ip_monitor_master/current_ip.txt

# 被控端 API 地址列表（用逗号分隔）
slave_api_urls = http://192.168.1.100:5000/update_dns,http://192.168.1.101:5000/update_dns

# 通讯密钥
secret_key = your_very_secret_key_here_change_this

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
```

### 被控端配置 (slave_config.ini)

```ini
[DEFAULT]
# 监听的 IP 地址
listen_host = 0.0.0.0

# 监听的端口
listen_port = 5000

# XrayR 的 dns.json 文件路径
dns_file_path = /etc/XrayR/dns.json

# 通讯密钥
secret_key = your_very_secret_key_here_change_this

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
```

## 服务管理

### 使用 systemd 管理服务

1. **创建主控端服务文件**
   ```bash
   sudo nano /etc/systemd/system/ip-monitor-master.service
   ```

   ```ini
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
   ```

2. **创建被控端服务文件**
   ```bash
   sudo nano /etc/systemd/system/ip-monitor-slave.service
   ```

   ```ini
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
   ```

3. **启动和管理服务**
   ```bash
   # 重新加载 systemd
   sudo systemctl daemon-reload

   # 启动服务
   sudo systemctl start ip-monitor-master
   sudo systemctl start ip-monitor-slave

   # 设置开机自启
   sudo systemctl enable ip-monitor-master
   sudo systemctl enable ip-monitor-slave

   # 查看服务状态
   sudo systemctl status ip-monitor-master
   sudo systemctl status ip-monitor-slave

   # 查看日志
   sudo journalctl -u ip-monitor-master -f
   sudo journalctl -u ip-monitor-slave -f
   ```

## 故障排除

### 常见问题

1. **主控端无法连接被控端**
   - 检查防火墙设置，确保端口5000开放
   - 验证被控端IP地址和端口是否正确
   - 检查网络连接是否正常

2. **被控端无法更新DNS文件**
   - 检查文件路径是否正确
   - 确认文件权限是否足够
   - 查看日志文件获取详细错误信息

3. **服务启动失败**
   - 检查配置文件语法是否正确
   - 确认二进制文件有执行权限
   - 查看系统日志获取错误信息

### 日志查看

```bash
# 查看主控端日志
tail -f /opt/ip_monitor_master/master.log

# 查看被控端日志
tail -f /opt/ip_monitor_slave/slave.log

# 查看系统日志
sudo journalctl -u ip-monitor-master -f
sudo journalctl -u ip-monitor-slave -f
```

### 手动测试

1. **测试主控端IP检测**
   ```bash
   cd /opt/ip_monitor_master/
   ./master --test-ip
   ```

2. **测试被控端API**
   ```bash
   curl -X POST http://slave-ip:5000/update_dns \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer your_secret_key" \
     -d '{"new_ip": "1.2.3.4"}'
   ```

## 安全建议

1. **修改默认密钥**
   - 在配置文件中修改 `secret_key` 为复杂的随机字符串
   - 确保主控端和被控端使用相同的密钥

2. **防火墙配置**
   - 只开放必要的端口（5000）
   - 限制访问来源IP

3. **文件权限**
   - 确保配置文件和日志文件权限适当
   - 避免使用root用户运行（如可能）

## 更新和升级

1. **备份当前配置**
   ```bash
   cp master_config.ini master_config.ini.backup
   cp slave_config.ini slave_config.ini.backup
   ```

2. **下载新版本**
   ```bash
   git pull origin main
   ```

3. **重启服务**
   ```bash
   sudo systemctl restart ip-monitor-master
   sudo systemctl restart ip-monitor-slave
   ```

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 许可证

本项目采用 MIT 许可证。

## 联系方式

如有问题或建议，请通过 GitHub Issues 联系我们。
