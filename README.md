# 🐳 Docker Rsync Transfer

<div align="center">

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

基于 Docker 的通用数据迁移工具，使用 rsync + inotify 实现实时数据同步，主要服务于 NFS 迁移方面。

</div>

---

## 📖 目录

- [特性](#-特性)
- [架构](#-架构)
- [快速开始](#-快速开始)(Working)
- [配置说明](#-配置说明)(Working)
- [使用指南](#-使用指南)(Working)
- [监控与维护](#-监控与维护)
- [故障排查](#-故障排查)

## ✨ 特性

- 🐳 **完全容器化** - 无需担心系统依赖和环境差异
- 🔄 **实时同步** - 基于 inotify 的文件系统事件监控
- 📊 **详细日志** - 完整的同步和错误日志记录
- 🚀 **一键部署** - 简单的命令行工具，快速上手
- 🌍 **跨平台** - 支持所有主流 Linux 发行版
- 📦 **轻量级** - 基于 Alpine Linux，镜像体积小
- 🔧 **灵活配置** - 支持宿主机NFS挂载、Docker Volume挂载NFS

## 🏗 架构

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   Source Server         │         │   Target Server         │
│  ┌──────────────────┐   │         │  ┌──────────────────┐   │
│  │  Source Data     │   │         │  │  Target Data     │   │
│  │  Directory       │   │         │  │  Directory       │   │
│  └────────┬─────────┘   │         │  └────────▲─────────┘   │
│           │             │         │           │             │
│  ┌────────▼─────────┐   │  rsync  │  ┌────────┴─────────┐   │
│  │  inotify         │   │  over   │  │  rsync daemon    │   │
│  │  monitoring      │───┼────────►│  │  (port 873)      │   │
│  └──────────────────┘   │  TCP    │  └──────────────────┘   │
│                         │         │                         │
│  Docker Container       │         │  Docker Container       │
└─────────────────────────┘         └─────────────────────────┘
```

## 📊 监控与维护

### 查看同步状态

```bash
# 实时日志
docker-compose -f source/docker-compose.yml logs -f rsync-source

# 同步日志
tail -f source/logs/rsync.log

# inotify 事件日志
tail -f source/logs/inotify.log
```

### 数据一致性验证

```bash
# 源端数据大小
docker-compose -f source/docker-compose.yml exec rsync-source du -sh /data

# 目标端数据大小
docker-compose -f target/docker-compose.yml exec rsync-target du -sh /data

# 文件数量对比
docker-compose -f source/docker-compose.yml exec rsync-source find /data -type f | wc -l
docker-compose -f target/docker-compose.yml exec rsync-target find /data -type f | wc -l
```

### 性能监控

```bash
# 查看容器资源使用
docker stats cfs-migration-source cfs-migration-target

# 查看网络流量
docker-compose -f source/docker-compose.yml exec rsync-source \
  cat /proc/net/dev | grep eth0
```

## 🔧 故障排查

### 问题 1: 连接失败

```bash
# 检查网络连通性
docker-compose -f source/docker-compose.yml exec rsync-source \
  ping <target-host>

# 检查端口
docker-compose -f source/docker-compose.yml exec rsync-source \
  nc -zv <target-host> 873

# 检查防火墙（在宿主机）
sudo iptables -L -n | grep 873
```

**解决方案：**
- 确保目标端 873 端口开放
- 检查云服务商安全组规则
- 验证 Docker 网络配置

### 问题 2: 认证失败

```bash
# 检查密码文件
docker-compose -f target/docker-compose.yml exec rsync-target \
  cat /etc/rsync/rsync.pass

# 验证配置
docker-compose -f target/docker-compose.yml exec rsync-target \
  cat /etc/rsyncd.conf
```

**解决方案：**
- 确保源端和目标端密码一致
- 检查密码文件权限（应为 600）
- 验证用户名配置

### 问题 3: 同步延迟

```bash
# 检查 inotify 事件
docker-compose -f source/docker-compose.yml exec rsync-source \
  tail -f /var/log/inotify.log

# 检查 rsync 进程
docker-compose -f source/docker-compose.yml exec rsync-source \
  ps aux | grep rsync
```

**解决方案：**
- 增加 inotify 监听限制（见高级配置）
- 调整 rsync 参数优化性能
- 检查网络带宽

### 问题 4: 权限错误

```bash
# 检查目录权限
docker-compose exec rsync-target ls -ld /data
docker-compose exec rsync-source ls -ld /data

# 检查文件所有者
docker-compose exec rsync-target ls -l /data/
```

**解决方案：**
- 确保容器以 root 运行（默认配置）
- 检查宿主机目录权限
- 如使用 NFS，检查 NFS 导出选项

---

<div align="center">

**欢迎 ⭐️ Star！**

Made with ❤️ by [MoonWX](https://github.com/MoonWX)

</div>
