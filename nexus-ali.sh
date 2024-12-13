#!/bin/bash

# 设置日志文件
LOG_FILE="install.log"

# 记录日志的函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 检查并开启 sudo 模式
if [ "$EUID" -ne 0 ]; then
    log "需要 root 权限运行此脚本"
    exit 1
fi

# 设置 Prover Id
PROVER_ID=""
if [ $# -eq 1 ]; then
    PROVER_ID=$1
    log "使用 Prover Id: $PROVER_ID"
fi

# 检查命令执行结果
check_result() {
    if [ $? -eq 0 ]; then
        log "✅ $1 成功"
    else
        log "❌ $1 失败"
        exit 1
    fi
}

# 开始安装
log "开始安装..."
# 安装openssl
sudo yum install openssl-devel -y
check_result "安装 openssl"

# 安装 git 和 cargo
log "正在安装 git 和 cargo..."
yum install -y git
check_result "安装 git"

yum install -y cargo
check_result "安装 cargo"

# 安装 expect
log "正在安装 expect..."
yum install -y expect
check_result "安装 expect"

# 安装 rustup
log "正在安装 rustup..."
expect -c '
set timeout -1
spawn bash -c "curl --proto \"=https\" --tlsv1.2 -sSf https://sh.rustup.rs | sh"
expect "Continue"
send "y\r"
expect ">"
send "1\r"
expect eof
'
check_result "安装 rustup"

# 设置环境变量
log "正在设置环境变量..."
source "$HOME/.cargo/env"
check_result "设置环境变量"

# 安装 protoc
log "正在安装 protoc..."

# 安装 unzip（如果没有）
log "检查并安装 unzip..."
if ! command -v unzip &> /dev/null; then
    yum install -y unzip
    check_result "安装 unzip"
fi

# 下载 protoc
log "下载 protoc..."
wget https://github.com/protocolbuffers/protobuf/releases/download/v29.1/protoc-29.1-linux-x86_64.zip
check_result "下载 protoc"

# 解压到 /usr/local
log "解压 protoc..."
unzip -o protoc-29.1-linux-x86_64.zip -d /usr/local
check_result "解压 protoc"

# 设置权限
log "设置权限..."
chmod 755 /usr/local/bin/protoc
check_result "设置 protoc 权限"

# 清理下载文件
log "清理临时文件..."
rm -f protoc-29.1-linux-x86_64.zip
check_result "清理临时文件"

# 验证安装
log "验证 protoc 安装..."
/usr/local/bin/protoc --version
check_result "验证 protoc"

# 安装 nexus cli
log "正在安装 nexus cli..."

# 安装 tmux
yum install -y tmux
check_result "安装 tmux"

# 在新的 tmux 会话中运行
tmux new-session -d -s nexus "expect -c '
set timeout -1
spawn bash -c \"curl https://cli.nexus.xyz/ | sh\"
expect {
    \"agree\" {
        send \"y\r\"
        exp_continue
    }
    \">\" {
        send \"${PROVER_ID}\r\"
    }
}
expect eof
' > nexus.log 2>&1"

log "nexus 已在 tmux 会话中启动，使用 'tmux attach -t nexus' 查看"
