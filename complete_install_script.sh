#!/bin/bash
# 범용 Paper 1.21.6 설치 스크립트

exec > >(tee /var/log/minecraft-install.log) 2>&1
echo "=== Paper 1.21.6 Installation Started ==="
echo "Time: $(date)"
echo "OS Detection: $(cat /etc/os-release | grep PRETTY_NAME)"

# OS 감지 및 패키지 매니저 설정
if [ -f /etc/debian_version ]; then
    # Ubuntu/Debian
    PKG_UPDATE="apt update && apt upgrade -y"
    PKG_INSTALL="apt install -y"
    USER_HOME="/home/ubuntu"
    SERVER_USER="ubuntu"
elif [ -f /etc/redhat-release ] || [ -f /etc/amazon-linux-release ]; then
    # Amazon Linux/CentOS/RHEL
    PKG_UPDATE="yum update -y"
    PKG_INSTALL="yum install -y"
    USER_HOME="/home/ec2-user"
    SERVER_USER="ec2-user"
else
    echo "Unsupported OS"
    exit 1
fi

echo "Using package manager: $PKG_INSTALL"
echo "User home: $USER_HOME"

# 시스템 업데이트 및 패키지 설치
$PKG_UPDATE

# Java 21 설치 (OS별 다른 패키지명)
if [ -f /etc/debian_version ]; then
    $PKG_INSTALL openjdk-21-jdk screen wget unzip curl jq
elif [ -f /etc/amazon-linux-release ]; then
    # Amazon Linux 2023
    $PKG_INSTALL java-21-amazon-corretto screen wget unzip curl jq
else
    # Amazon Linux 2 또는 기타
    amazon-linux-extras install java-openjdk21 -y
    $PKG_INSTALL screen wget unzip curl jq
fi

# Java 버전 확인
java -version

# 서버 디렉토리 생성
mkdir -p $USER_HOME/minecraft/{plugins,logs,backups,config}
cd $USER_HOME/minecraft

# Paper 1.21.6 다운로드
echo "Downloading Paper 1.21.6..."
wget -O paper.jar "https://api.papermc.io/v2/projects/paper/versions/1.21.6/builds/48/downloads/paper-1.21.6-48.jar"

# EULA 동의
echo "eula=true" > eula.txt

# 서버 설정
cat > server.properties << 'EOF'
server-port=25565
max-players=10
online-mode=true
difficulty=easy
gamemode=survival
motd=§6Paper 1.21.6 Server! §b🎈
view-distance=10
simulation-distance=10
spawn-protection=16
allow-nether=true
generate-structures=true
spawn-monsters=true
spawn-animals=true
white-list=false
enforce-whitelist=false
pvp=true
EOF

# 시작 스크립트
cat > start.sh << 'EOF'
#!/bin/bash
cd $USER_HOME/minecraft
java -Xms1800M -Xmx1800M \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC \
  -XX:+AlwaysPreTouch \
  -XX:G1NewSizePercent=30 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 \
  -XX:G1HeapWastePercent=5 \
  -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 \
  -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1 \
  --add-modules=jdk.incubator.vector \
  -jar paper.jar --nogui
EOF
chmod +x start.sh

# 경로 수정된 시작 스크립트
sed -i "s|\$USER_HOME|$USER_HOME|g" start.sh

cat > start_screen.sh << 'EOF'
#!/bin/bash
cd $USER_HOME/minecraft
screen -S minecraft -dm bash start.sh
echo "Paper server started in screen session 'minecraft'"
echo "Commands:"
echo "  screen -r minecraft  # Access console"
echo "  Ctrl+A, D          # Detach from console"
EOF
chmod +x start_screen.sh

# 경로 수정
sed -i "s|\$USER_HOME|$USER_HOME|g" start_screen.sh

cat > server_control.sh << 'EOF'
#!/bin/bash
case "$1" in
    start)
        echo "Starting Minecraft server..."
        cd $USER_HOME/minecraft && ./start_screen.sh
        ;;
    stop)
        echo "Stopping Minecraft server..."
        screen -S minecraft -p 0 -X eval 'stuff "stop\015"'
        ;;
    restart)
        echo "Restarting Minecraft server..."
        screen -S minecraft -p 0 -X eval 'stuff "stop\015"'
        sleep 10
        cd $USER_HOME/minecraft && ./start_screen.sh
        ;;
    console)
        echo "Connecting to server console (Ctrl+A, D to detach)..."
        screen -r minecraft
        ;;
    status)
        if screen -list | grep -q "minecraft"; then
            echo "✅ Server is running"
            echo "Players online:"
            screen -S minecraft -p 0 -X eval 'stuff "list\015"'
        else
            echo "❌ Server is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|console|status}"
        ;;
esac
EOF
chmod +x server_control.sh

# 경로 수정
sed -i "s|\$USER_HOME|$USER_HOME|g" server_control.sh

# 자동 종료 스크립트 (15분 idle)
cat > auto_shutdown.sh << 'EOF'
#!/bin/bash
IDLE_TIME=900  # 15분
CHECK_INTERVAL=60  # 1분마다 체크
COUNTER=0

echo "Auto-shutdown monitor started at $(date)"
echo "Will shutdown after $IDLE_TIME seconds of no players"

while true; do
    sleep $CHECK_INTERVAL
    
    if ! screen -list | grep -q "minecraft"; then
        echo "Server not running. Monitor stopping."
        exit 0
    fi
    
    # 플레이어 수 확인
    screen -S minecraft -p 0 -X eval 'stuff "list\015"'
    sleep 2
    
    PLAYER_COUNT=$(tail -20 $USER_HOME/minecraft/logs/latest.log | grep -E "There are [0-9]+ of a max" | tail -1 | grep -oE "[0-9]+" | head -1)
    
    if [ -z "$PLAYER_COUNT" ] || [ "$PLAYER_COUNT" -eq 0 ]; then
        COUNTER=$((COUNTER + CHECK_INTERVAL))
        echo "$(date): No players online. Idle time: ${COUNTER}/${IDLE_TIME} seconds"
        
        if [ $COUNTER -eq 600 ]; then
            screen -S minecraft -p 0 -X eval 'stuff "say §e⚠ Server will shutdown in 5 minutes due to inactivity\015"'
        elif [ $COUNTER -eq 840 ]; then
            screen -S minecraft -p 0 -X eval 'stuff "say §c⚠ Server will shutdown in 1 minute!\015"'
        elif [ $COUNTER -ge $IDLE_TIME ]; then
            echo "$(date): Idle time exceeded. Shutting down..."
            screen -S minecraft -p 0 -X eval 'stuff "say §c🛑 Server shutting down due to inactivity\015"'
            sleep 5
            screen -S minecraft -p 0 -X eval 'stuff "stop\015"'
            sleep 30
            sudo systemctl poweroff
            exit 0
        fi
    else
        if [ $COUNTER -gt 0 ]; then
            echo "$(date): Players online ($PLAYER_COUNT). Resetting idle counter."
        fi
        COUNTER=0
    fi
done
EOF
chmod +x auto_shutdown.sh

# 경로 수정
sed -i "s|\$USER_HOME|$USER_HOME|g" auto_shutdown.sh

# 소유권 변경
chown -R $SERVER_USER:$SERVER_USER $USER_HOME/minecraft

# 방화벽 설정 (OS별 다름)
if command -v ufw >/dev/null 2>&1; then
    # Ubuntu
    ufw allow 25565/tcp
    ufw --force enable
elif command -v firewall-cmd >/dev/null 2>&1; then
    # Amazon Linux 2023/CentOS
    firewall-cmd --permanent --add-port=25565/tcp
    firewall-cmd --reload
else
    echo "No firewall configuration needed or firewall command not found"
fi

# systemd 서비스 생성
cat > /etc/systemd/system/minecraft.service << EOF
[Unit]
Description=Paper 1.21.6 Minecraft Server
After=network.target

[Service]
Type=forking
User=$SERVER_USER
WorkingDirectory=$USER_HOME/minecraft
ExecStart=$USER_HOME/minecraft/start_screen.sh
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "stop\\015"'
ExecStop=/bin/sleep 10
RemainAfterExit=yes
RestartSec=15
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화 및 시작
systemctl enable minecraft.service
systemctl start minecraft.service

# 설치 완료 정보
cat > $USER_HOME/minecraft/installation_complete.txt << EOF
========================================
Paper 1.21.6 Server Installation Complete
========================================
Time: $(date)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Java: $(java -version 2>&1 | head -1)

Connection: [YOUR-EC2-PUBLIC-IP]:25565

Server Management:
  $USER_HOME/minecraft/server_control.sh start    # Start server
  $USER_HOME/minecraft/server_control.sh stop     # Stop server
  $USER_HOME/minecraft/server_control.sh console  # Access console
  $USER_HOME/minecraft/server_control.sh status   # Check status

Auto-shutdown: 15 minutes after last player leaves
Server files: $USER_HOME/minecraft/
User: $SERVER_USER

First steps:
1. Get your EC2 public IP address
2. Connect with Minecraft 1.21.6 client
3. Use /op <username> to become admin

========================================
EOF

echo "=== Installation completed successfully! ==="
echo "Server will be ready in 5-10 minutes"
echo "Check $USER_HOME/minecraft/installation_complete.txt for details"
