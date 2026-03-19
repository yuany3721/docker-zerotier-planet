#!/bin/bash

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_title() {
    echo -e "${BLUE}$1${NC}"
}

# 检查环境
check_environment() {
    print_info "检查环境..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        echo "安装指南: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        echo "安装指南: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # 检查 .env 文件
    if [ ! -f .env ]; then
        print_error ".env 文件不存在"
        print_info "请复制 .env 示例并配置: cp .env.example .env"
        exit 1
    fi
    
    # 加载环境变量
    set -a
    source .env
    set +a
    
    # 检查 IP 地址是否已配置
    if [ "$IP_ADDR4" = "your_ipv4_address_here" ] || [ -z "$IP_ADDR4" ]; then
        print_warn "IP_ADDR4 未配置，尝试自动获取..."
        AUTO_IP=$(curl -s https://ipv4.icanhazip.com/ 2>/dev/null || echo "")
        if [ -n "$AUTO_IP" ]; then
            print_info "自动获取到 IPv4: $AUTO_IP"
            read -p "是否使用此 IP? (y/n): " use_auto_ip
            if [[ "$use_auto_ip" =~ ^[Yy]$ ]]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    sed -i '' "s/IP_ADDR4=.*/IP_ADDR4=$AUTO_IP/" .env
                else
                    # Linux
                    sed -i "s/IP_ADDR4=.*/IP_ADDR4=$AUTO_IP/" .env
                fi
                IP_ADDR4=$AUTO_IP
                print_info "已更新 .env 文件"
            else
                print_error "请手动配置 IP_ADDR4 后重试"
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
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${DOCKER_IMAGE}"; then
        print_warn "镜像 ${DOCKER_IMAGE} 不存在"
        return 1
    fi
    return 0
}

# 构建镜像
build_image() {
    print_info "开始构建镜像..."
    print_info "这可能需要 5-15 分钟，请耐心等待"
    
    # 检查 Dockerfile 是否存在
    if [ ! -f Dockerfile ]; then
        print_error "Dockerfile 不存在，无法构建"
        exit 1
    fi
    
    # 开始构建
    if ! docker build -t zerotier-planet:local .; then
        print_error "镜像构建失败"
        exit 1
    fi
    
    print_info "镜像构建完成"
}

# 启动服务
start_service() {
    print_info "启动服务..."
    
    # 检查是否已有容器在运行
    if docker ps --format "{{.Names}}" | grep -q "^myztplanet$"; then
        print_warn "容器 myztplanet 已在运行"
        read -p "是否先停止旧容器? (y/n): " stop_old
        if [[ "$stop_old" =~ ^[Yy]$ ]]; then
            docker compose down
        else
            print_info "跳过启动"
            return 0
        fi
    fi
    
    # 启动
    if ! docker compose up -d; then
        print_error "服务启动失败"
        exit 1
    fi
    
    print_info "等待服务初始化..."
    sleep 10
    
    # 检查容器状态
    if docker ps --format "{{.Names}}" | grep -q "^myztplanet$"; then
        print_info "服务启动成功"
        show_info
    else
        print_error "服务启动失败，请检查日志"
        docker compose logs
        exit 1
    fi
}

# 停止服务
stop_service() {
    print_info "停止服务..."
    docker compose down
    print_info "服务已停止"
}

# 查看日志
view_logs() {
    docker compose logs -f
}

# 显示信息
show_info() {
    source .env
    
    # 获取密钥和 moon 文件名
    KEY=$(docker exec myztplanet sh -c 'cat /app/config/file_server.key' 2>/dev/null || echo "")
    MOON_NAME=$(docker exec myztplanet sh -c 'ls /app/dist | grep moon' 2>/dev/null | tr -d '\r' || echo "")
    
    echo ""
    print_title "========================================"
    print_title "     Zerotier Planet 服务信息"
    print_title "========================================"
    echo ""
    echo -e "🌐 ${GREEN}Web 管理界面:${NC} http://${IP_ADDR4}:${API_PORT}"
    echo -e "👤 ${GREEN}用户名:${NC} admin"
    echo -e "🔑 ${GREEN}默认密码:${NC} password"
    echo ""
    echo -e "📁 ${GREEN}配置文件目录:${NC} ${SCRIPT_DIR}/data/zerotier"
    echo ""
    
    if [ -n "$KEY" ]; then
        echo -e "🔐 ${GREEN}文件下载密钥:${NC} ${KEY}"
        echo ""
        echo -e "📥 ${GREEN}planet 文件下载链接:${NC}"
        echo "   http://${IP_ADDR4}:${FILE_PORT}/planet?key=${KEY}"
        echo ""
        
        if [ -n "$MOON_NAME" ]; then
            echo -e "📥 ${GREEN}moon 文件下载链接:${NC}"
            echo "   http://${IP_ADDR4}:${FILE_PORT}/${MOON_NAME}?key=${KEY}"
            echo ""
        fi
    fi
    
    echo -e "⚠️  ${YELLOW}请确保防火墙放行以下端口:${NC}"
    echo "   - ${ZT_PORT}/tcp"
    echo "   - ${ZT_PORT}/udp"
    echo "   - ${API_PORT}/tcp"
    echo "   - ${FILE_PORT}/tcp"
    echo ""
    echo -e "⚠️  ${RED}请及时修改默认密码！${NC}"
    print_title "========================================"
}

# 重置密码
reset_password() {
    print_info "重置密码..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^myztplanet$"; then
        print_error "容器未运行，请先启动服务"
        exit 1
    fi
    
    docker exec myztplanet sh -c 'cp /app/ztncui/src/etc/default.passwd /app/ztncui/src/etc/passwd'
    if [ $? -ne 0 ]; then
        print_error "重置密码失败"
        exit 1
    fi
    
    docker restart myztplanet
    if [ $? -ne 0 ]; then
        print_error "重启服务失败"
        exit 1
    fi
    
    print_info "密码已重置为默认值: password"
}

# 主流程
main() {
    echo ""
    print_title "========================================"
    print_title "  Docker Zerotier Planet 管理脚本"
    print_title "========================================"
    echo ""
    
    check_environment
    
    if ! check_image; then
        echo ""
        read -p "是否立即构建镜像? (y/n): " build_now
        if [[ "$build_now" =~ ^[Yy]$ ]]; then
            build_image
        else
            print_error "没有可用镜像，无法启动"
            print_info "请运行: $0 build"
            exit 1
        fi
    fi
    
    start_service
}

# 显示菜单
show_menu() {
    echo ""
    print_title "========================================"
    print_title "  Docker Zerotier Planet 管理菜单"
    print_title "========================================"
    echo ""
    echo "1. 启动服务"
    echo "2. 构建镜像"
    echo "3. 停止服务"
    echo "4. 重启服务"
    echo "5. 查看日志"
    echo "6. 查看服务信息"
    echo "7. 重置密码"
    echo "0. 退出"
    echo ""
    read -p "请输入选项 [0-7]: " choice
    
    case "$choice" in
        1)
            main
            ;;
        2)
            check_environment
            build_image
            ;;
        3)
            stop_service
            ;;
        4)
            stop_service
            sleep 2
            main
            ;;
        5)
            view_logs
            ;;
        6)
            show_info
            ;;
        7)
            reset_password
            ;;
        0)
            print_info "退出"
            exit 0
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
}

# 根据参数执行不同操作
case "${1:-}" in
    start)
        main
        ;;
    build)
        check_environment
        build_image
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        main
        ;;
    logs)
        view_logs
        ;;
    info)
        show_info
        ;;
    resetpwd)
        reset_password
        ;;
    menu)
        show_menu
        ;;
    "")
        # 如果没有参数，显示菜单
        show_menu
        ;;
    *)
        echo ""
        echo "Docker Zerotier Planet 管理脚本"
        echo ""
        echo "用法: $0 [命令]"
        echo ""
        echo "命令:"
        echo "  start     启动服务"
        echo "  build     构建镜像"
        echo "  stop      停止服务"
        echo "  restart   重启服务"
        echo "  logs      查看日志"
        echo "  info      查看服务信息"
        echo "  resetpwd  重置密码"
        echo "  menu      显示交互式菜单"
        echo ""
        echo "如果不带参数，默认显示交互式菜单"
        echo ""
        exit 1
        ;;
esac
