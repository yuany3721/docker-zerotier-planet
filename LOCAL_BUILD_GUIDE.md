# Docker Zerotier Planet 本地构建与部署指南

本文档描述如何将项目从使用预构建镜像改为本地构建，并使用 Docker Compose 部署。

---

## 一、前置依赖

### 1. 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+ 等) |
| **内核版本** | Linux Kernel 5.x 及以上 |
| **架构** | x86_64 (amd64) 或 ARM64 |
| **内存** | 建议 2GB 及以上 |
| **磁盘空间** | 建议 10GB 及以上可用空间 |

### 2. 必需软件

```bash
# Docker (必需，版本 20.10.0+)
docker --version

# Docker Compose (必需，版本 2.0.0+)
docker compose version

# Git (必需)
git --version

# curl (必需)
curl --version
```

### 3. 安装依赖（如未安装）

**Ubuntu/Debian:**
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Docker
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 将当前用户加入 docker 组
sudo usermod -aG docker $USER
# 重新登录或执行以下命令使配置生效
newgrp docker
```

**CentOS/RHEL:**
```bash
# 安装 Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户加入 docker 组
sudo usermod -aG docker $USER
```

---

## 二、本地构建步骤

### 1. 克隆你的 Fork 仓库

```bash
# 如果你还没有克隆仓库
git clone git@github.com:yuany3721/docker-zerotier-planet.git
cd docker-zerotier-planet

# 如果已经克隆了原始仓库，修改远程地址
git remote set-url origin git@github.com:yuany3721/docker-zerotier-planet.git
git remote add upstream https://github.com/xubiaolin/docker-zerotier-planet.git
```

### 2. 本地构建镜像

#### 方式 A：使用 Docker 命令直接构建

```bash
# 基础构建（推荐用于开发和测试）
docker build -t zerotier-planet:local .

# 使用特定版本标签
docker build -t zerotier-planet:local -t zerotier-planet:v1.0.0 .

# 详细输出构建过程
docker build --progress=plain -t zerotier-planet:local .

# 不使用缓存（完全重新构建）
docker build --no-cache -t zerotier-planet:local .
```

**构建参数说明：**

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `TAG` | ZeroTier 版本标签 | actions |

```bash
# 使用特定版本的 ZeroTier
docker build --build-arg TAG=1.12.2 -t zerotier-planet:local .
```

#### 方式 B：使用 buildx 构建多架构镜像（高级）

```bash
# 创建 buildx 构建器
docker buildx create --name zerotier-builder --use

# 构建多架构镜像并推送到仓库（如果需要）
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-dockerhub-username/zerotier-planet:local \
  --push .

# 只构建当前架构并加载到本地
docker buildx build --platform linux/amd64 \
  -t zerotier-planet:local \
  --load .
```

### 3. 验证构建

```bashn# 查看构建的镜像
docker images | grep zerotier-planet

# 检查镜像详情
docker inspect zerotier-planet:local

# 运行测试容器
docker run --rm -it zerotier-planet:local zerotier-one --version
```

---

## 三、Docker Compose 部署

### 1. 创建目录结构

```bash
# 创建项目目录
mkdir -p docker-zerotier-planet/{data,config}
cd docker-zerotier-planet

# 目录结构说明
# docker-zerotier-planet/
# ├── docker-compose.yml      # Docker Compose 配置文件
# ├── .env                    # 环境变量文件
# ├── Dockerfile              # 本地构建用（可选，如果你修改了代码）
# ├── data/                   # 数据持久化目录
# │   ├── zerotier/
# │   │   ├── dist/          # planet 和 moon 文件
# │   │   ├── ztncui/        # ztncui 配置
# │   │   ├── one/           # zerotier-one 数据
# │   │   └── config/        # 配置文件
# │   └── ...
# └── patch/                  # 补丁文件（如果使用本地构建）
```

### 2. Docker Compose 配置

创建 `docker-compose.yml` 文件：

```yaml
version: "3.8"

services:
  zerotier-planet:
    # 使用本地构建的镜像
    image: zerotier-planet:local
    # 或者如果你推送到 Docker Hub，使用：
    # image: ${DOCKER_IMAGE:-zerotier-planet:local}
    
    container_name: myztplanet
    
    # 如果使用本地 Dockerfile 构建，取消下面这行的注释
    # build:
    #   context: .
    #   dockerfile: Dockerfile
    #   args:
    #     - TAG=${ZEROTIER_TAG:-actions}
    
    restart: unless-stopped
    
    # 网络配置
    networks:
      - zerotier-network
    
    # 端口映射
    ports:
      - "${ZT_PORT}:${ZT_PORT}"
      - "${ZT_PORT}:${ZT_PORT}/udp"
      - "${API_PORT}:${API_PORT}"
      - "${FILE_PORT}:${FILE_PORT}"
    
    # 环境变量
    environment:
      - IP_ADDR4=${IP_ADDR4}
      - IP_ADDR6=${IP_ADDR6}
      - ZT_PORT=${ZT_PORT}
      - API_PORT=${API_PORT}
      - FILE_SERVER_PORT=${FILE_PORT}
      - FILE_KEY=${FILE_KEY:-}
      - TZ=${TZ:-Asia/Shanghai}
    
    # 数据卷挂载
    volumes:
      - ./data/zerotier/dist:/app/dist
      - ./data/zerotier/ztncui:/app/ztncui
      - ./data/zerotier/one:/var/lib/zerotier-one
      - ./data/zerotier/config:/app/config
    
    # 特权模式（某些功能可能需要）
    # privileged: true
    
    # 资源限制（可选）
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    
    # 健康检查（可选）
    healthcheck:
      test: ["CMD", "zerotier-one", "-h"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  zerotier-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 3. 环境变量配置文件 (.env)

创建 `.env` 文件：

```bash
# ==========================================
# Docker Zerotier Planet 配置文件
# ==========================================

# ------------------------------------------
# 镜像配置
# ------------------------------------------
# 使用的镜像名称
DOCKER_IMAGE=zerotier-planet:local

# ZeroTier 版本标签（构建时使用）
ZEROTIER_TAG=actions

# ------------------------------------------
# 网络配置
# ------------------------------------------
# 你的公网 IPv4 地址（必填）
# 获取方式：curl -s https://ipv4.icanhazip.com/
IP_ADDR4=your_ipv4_address_here

# 你的公网 IPv6 地址（可选，可为空）
# 获取方式：curl -s https://ipv6.icanhazip.com/
IP_ADDR6=

# ------------------------------------------
# 端口配置
# ------------------------------------------
# ZeroTier 通信端口（默认 9994，建议保持默认）
ZT_PORT=9994

# Web 管理界面端口（默认 3443）
API_PORT=3443

# 文件下载服务器端口（默认 3000）
FILE_PORT=3000

# 文件下载密钥（可选，自动生成）
FILE_KEY=

# ------------------------------------------
# 其他配置
# ------------------------------------------
# 时区设置
TZ=Asia/Shanghai

# GitHub 镜像加速地址（可选）
GH_MIRROR=https://mirror.ghproxy.com/

# ------------------------------------------
# 数据路径配置
# ------------------------------------------
# 数据存储根目录（相对路径）
DATA_PATH=./data/zerotier

# 配置文件路径
CONFIG_PATH=./data/zerotier/config

# Dist 文件路径（planet/moon）
DIST_PATH=./data/zerotier/dist

# ztncui 路径
ZTNCUI_PATH=./data/zerotier/ztncui
```

### 4. 启动脚本（可选但推荐）

创建 `start.sh` 脚本来自动化启动流程：

```bash
#!/bin/bash

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查环境
check_environment() {
    print_info "检查环境..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查 .env 文件
    if [ ! -f .env ]; then
        print_error ".env 文件不存在，请先创建配置文件"
        exit 1
    fi
    
    # 检查 IP 地址是否已配置
    source .env
    if [ "$IP_ADDR4" = "your_ipv4_address_here" ] || [ -z "$IP_ADDR4" ]; then
        print_warn "IP_ADDR4 未配置，尝试自动获取..."
        AUTO_IP=$(curl -s https://ipv4.icanhazip.com/ 2>/dev/null || echo "")
        if [ -n "$AUTO_IP" ]; then
            print_info "自动获取到 IPv4: $AUTO_IP"
            read -p "是否使用此 IP? (y/n): " use_auto_ip
            if [[ "$use_auto_ip" =~ ^[Yy]$ ]]; then
                sed -i "s/IP_ADDR4=.*/IP_ADDR4=$AUTO_IP/" .env
                print_info "已更新 .env 文件"
            else
                print_error "请手动配置 IP_ADDR4"
                exit 1
            fi
        else
            print_error "无法自动获取 IP 地址，请手动配置 .env 文件"
            exit 1
        fi
    fi
    
    # 创建必要的目录
    mkdir -p data/zerotier/{dist,ztncui,one,config}
    
    print_info "环境检查完成"
}

# 检查镜像是否存在
check_image() {
    source .env
    if ! docker images | grep -q "${DOCKER_IMAGE%%:*}"; then
        print_warn "镜像 ${DOCKER_IMAGE} 不存在，需要构建"
        return 1
    fi
    return 0
}

# 构建镜像
build_image() {
    print_info "开始构建镜像..."
    
    # 使用本地 Dockerfile 构建
    if [ -f Dockerfile ]; then
        docker build -t zerotier-planet:local .
    else
        print_error "Dockerfile 不存在，无法构建"
        exit 1
    fi
    
    print_info "镜像构建完成"
}

# 启动服务
start_service() {
    print_info "启动服务..."
    
    # 检查是否已有容器在运行
    if docker ps | grep -q "myztplanet"; then
        print_warn "容器 myztplanet 已在运行，先停止..."
        docker compose down
    fi
    
    # 启动
    docker compose up -d
    
    print_info "等待服务启动..."
    sleep 10
    
    # 检查容器状态
    if docker ps | grep -q "myztplanet"; then
        print_info "服务启动成功"
        show_info
    else
        print_error "服务启动失败，请检查日志"
        docker compose logs
        exit 1
    fi
}

# 显示信息
show_info() {
    source .env
    
    # 获取密钥
    KEY=$(docker exec myztplanet sh -c 'cat /app/config/file_server.key' 2>/dev/null || echo "")
    MOON_NAME=$(docker exec myztplanet sh -c 'ls /app/dist | grep moon' 2>/dev/null || echo "")
    
    echo ""
    echo "========================================"
    echo "     Zerotier Planet 部署成功"
    echo "========================================"
    echo ""
    echo "🌐 Web 管理界面: http://${IP_ADDR4}:${API_PORT}"
    echo "👤 用户名: admin"
    echo "🔑 密码: password"
    echo ""
    echo "📁 配置文件目录: ${SCRIPT_DIR}/data/zerotier"
    echo ""
    if [ -n "$KEY" ]; then
        echo "🔐 文件下载密钥: ${KEY}"
        echo ""
        echo "📥 planet 文件下载:"
        echo "   http://${IP_ADDR4}:${FILE_PORT}/planet?key=${KEY}"
        echo ""
        if [ -n "$MOON_NAME" ]; then
            echo "📥 moon 文件下载:"
            echo "   http://${IP_ADDR4}:${FILE_PORT}/${MOON_NAME}?key=${KEY}"
            echo ""
        fi
    fi
    echo "⚠️  请确保防火墙放行以下端口:"
    echo "   - ${ZT_PORT}/tcp"
    echo "   - ${ZT_PORT}/udp"
    echo "   - ${API_PORT}/tcp"
    echo "   - ${FILE_PORT}/tcp"
    echo ""
    echo "⚠️  请及时修改默认密码！"
    echo "========================================"
}

# 主流程
main() {
    echo "========================================"
    echo "  Docker Zerotier Planet 启动脚本"
    echo "========================================"
    echo ""
    
    check_environment
    
    if ! check_image; then
        read -p "是否立即构建镜像? (y/n): " build_now
        if [[ "$build_now" =~ ^[Yy]$ ]]; then
            build_image
        else
            print_error "没有可用镜像，无法启动"
            exit 1
        fi
    fi
    
    start_service
}

# 根据参数执行不同操作
case "${1:-start}" in
    start)
        main
        ;;
    build)
        check_environment
        build_image
        ;;
    stop)
        print_info "停止服务..."
        docker compose down
        ;;
    restart)
        print_info "重启服务..."
        docker compose down
        sleep 2
        main
        ;;
    logs)
        docker compose logs -f
        ;;
    info)
        show_info
        ;;
    *)
        echo "用法: $0 {start|build|stop|restart|logs|info}"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动服务（默认）"
        echo "  build   - 构建镜像"
        echo "  stop    - 停止服务"
        echo "  restart - 重启服务"
        echo "  logs    - 查看日志"
        echo "  info    - 显示服务信息"
        exit 1
        ;;
esac
```

赋予执行权限：
```bash
chmod +x start.sh
```

---

## 四、部署操作步骤

### 1. 首次部署

```bash
# 1. 进入项目目录
cd docker-zerotier-planet

# 2. 配置环境变量
# 复制示例配置（如果有）
cp .env.example .env

# 编辑 .env 文件
nano .env  # 或 vim .env

# 3. 构建镜像（如果使用本地构建）
docker build -t zerotier-planet:local .

# 或使用一键启动脚本
./start.sh build

# 4. 启动服务
docker compose up -d

# 或使用一键启动脚本
./start.sh start
```

### 2. 常用管理命令

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 查看最后 100 行日志
docker compose logs --tail=100

# 停止服务
docker compose down

# 重启服务
docker compose restart

# 重新构建并启动
docker compose up -d --build

# 进入容器内部
docker exec -it myztplanet sh

# 查看容器资源使用
docker stats myztplanet
```

### 3. 更新操作

```bash
# 1. 拉取最新代码（如果有更新）
git pull origin master

# 2. 重新构建镜像
docker build --no-cache -t zerotier-planet:local .

# 3. 停止旧容器
docker compose down

# 4. 启动新容器（保留数据）
docker compose up -d

# 或使用一键脚本
./start.sh restart
```

---

## 五、问题排查

### 1. 构建失败

**问题：构建过程中网络超时**
```bash
# 解决方案：使用代理或镜像源
# 在 Dockerfile 中添加镜像源
sed -i 's|https://registry.npmmirror.com|https://your-mirror.com|g' Dockerfile
docker build -t zerotier-planet:local .
```

**问题：内存不足**
```bash
# 解决方案：增加交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 2. 容器启动失败

```bash
# 查看详细日志
docker compose logs

# 检查端口冲突
sudo lsof -i :9994
sudo lsof -i :3443
sudo lsof -i :3000

# 检查数据目录权限
ls -la data/zerotier/
sudo chown -R 1000:1000 data/zerotier/
```

### 3. 无法访问 Web 界面

```bash
# 检查容器状态
docker ps | grep myztplanet

# 检查端口映射
docker port myztplanet

# 检查防火墙
curl -v http://localhost:3443

# 测试本地访问
docker exec myztplanet wget -qO- http://localhost:3443
```

---

## 六、与原始仓库保持同步

```bash
# 1. 获取原始仓库更新
git fetch upstream

# 2. 查看更新内容
git log upstream/master --oneline -10

# 3. 合并更新到本地分支
git merge upstream/master

# 4. 解决冲突（如果有）
# 编辑冲突文件后
git add .
git commit -m "Merge upstream changes"

# 5. 推送到你的 fork
git push origin master

# 6. 重新构建镜像
docker build -t zerotier-planet:local .
docker compose up -d
```

---

## 七、高级配置

### 1. 使用 Docker Compose 构建

如果你希望在 `docker-compose up` 时自动构建：

```yaml
services:
  zerotier-planet:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        TAG: ${ZEROTIER_TAG:-actions}
    image: zerotier-planet:local
    # ... 其他配置
```

然后运行：
```bash
# 构建并启动
docker compose up -d --build
```

### 2. 多环境配置

创建多个环境文件：
- `.env.production` - 生产环境
- `.env.development` - 开发环境

使用时指定：
```bash
docker compose --env-file .env.production up -d
```

---

## 八、总结

### 文件清单

部署时需要以下文件：

```
docker-zerotier-planet/
├── docker-compose.yml     # Docker Compose 配置 ⭐
├── .env                   # 环境变量配置 ⭐
├── Dockerfile             # 本地构建用（如果使用本地构建）
├── start.sh               # 启动脚本（可选但推荐）
├── data/                  # 数据目录（自动创建）
└── LOCAL_BUILD_GUIDE.md   # 本文档
```

**必需文件：** ⭐ 标记的文件

### 快速开始命令

```bash
# 1. 克隆仓库
git clone git@github.com:yuany3721/docker-zerotier-planet.git
cd docker-zerotier-planet

# 2. 配置
nano .env  # 编辑配置

# 3. 构建（可选，如果使用预构建镜像则跳过）
docker build -t zerotier-planet:local .

# 4. 启动
docker compose up -d

# 5. 查看状态
docker compose ps
docker compose logs -f
```

---

**提示：**
- 首次构建可能需要 5-15 分钟，请耐心等待
- 建议在部署前先在本地测试构建
- 生产环境请确保配置强密码
- 定期备份 `data/zerotier` 目录

如有问题，请查看日志或提交 Issue。
