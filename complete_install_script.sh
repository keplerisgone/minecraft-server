#!/bin/bash
# install-paper.sh
# Paper 1.21.6 마인크래프트 서버 완전 설치 스크립트

set -e  # 에러 발생 시 스크립트 중단

echo "=== Paper 1.21.6 Minecraft Server Installation ==="
echo "Starting installation at $(date)"

# 시스템 업데이트 및 패키지 설치
echo "Installing required packages..."
apt update && apt upgrade -y
apt install -y openjdk-21-jdk screen wget unzip curl jq

# 서버 디렉토리 생성
echo "Creating server directories..."
mkdir -p /home/ubuntu/minecraft/{plugins,logs,backups,config}
cd /home/ubuntu/minecraft

# Paper 1.21.6 최신 빌드 다운로드
echo "Downloading Paper 1.21.6..."
PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.6/builds"
LATEST_BUILD=$(curl -s "$PAPER_URL" | jq -r '.builds[-1].build')
PAPER_JAR_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.6/builds/$LATEST_BUILD/downloads/paper-1.21.6-$LATEST_BUILD.jar"
wget -O paper.jar "$PAPER_JAR_URL"

# EULA 동의
echo "eula=true" > eula.txt

# 서버 설정 파일들 생성
echo "Creating configuration files..."

# server.properties
cat > server.properties << 'EOF'
server-name=AWS Paper 1.21.6 Server
server-port=25565
max-players=10
online-mode=true
difficulty=easy
gamemode=survival
allow-nether=true
generate-structures=true
spawn-protection=16
view-distance=10
simulation-distance=10
motd=§6Paper 1.21.6 - Chase the Skies! §b🎈
enable-command-block=false
spawn-monsters=true
spawn-animals=true
white-list=false
enforce-whitelist=false
pvp=true
player-idle-timeout=0
EOF

# Paper 설정 파일들 (간단 버전)
mkdir -p config

cat > config/paper-global.yml << 'EOF'
_version: 29
chunk-loading-basic:
  player-max-chunk-load-rate: 10.0
console:
  enable-brigadier-completions: true
logging:
  deobfuscate-stacktraces: true
misc:
  compression-level:
    network-compression-threshold: 256
  max-joins-per-tick: 5
  region-file-cache-size: 256
timings:
  enabled: true
  verbose: true
EOF

cat > config/paper-world-defaults.yml << 'EOF'
_version: 31
entities:
  spawning:
    per-player-mob-spawns: true
    scan-for-legacy-ender-dragon: true
chunks:
  auto-save-interval: default
  delay-chunk-unloads-by: 10s
  max-auto-save-chunks-per-tick: 24
misc:
  redstone-implementation: EIGENCRAFT
  update-pathfinding-on-block-update: true
EOF

# 시작 스크립트 생성
echo "Creating start scripts..."

cat > start.sh << 'EOF'
#!/bin/bash
cd /home/ubuntu/minecraft

java -Xms2G -Xmx2G \
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
  -XX:+UseStringDeduplication \
  --add-modules=jdk.incubator.vector \
  -jar paper.jar --nogui
EOF

chmod +x start.sh

cat > start_screen.sh << 'EOF'
#!/bin/bash
cd /home/ubuntu/minecraft
screen -S minecraft -dm bash start.sh
echo "Paper server started in screen session 'minecraft'"
echo "Use 'screen -r minecraft' to attach to console"
echo "Use Ctrl+A, D to detach from console"
EOF

chmod +x start_screen.sh

# 자동 종료 스크립트 생성
cat > auto_shutdown.sh << 'EOF'
#!/bin/bash
# 15분간 플레이어가 없으면 EC2 인스턴스 자동 종료

IDLE_TIME=900  # 15분
CHECK_INTERVAL=60  # 1분마다 체크
COUNTER=0

echo "Auto-shutdown monitor started at $(date)"

while true; do
    sleep $CHECK_INTERVAL
    
    if ! screen -list | grep -q "minecraft"; then
        echo "Server not running. Monitor stopping."
        exit 0
    fi
    
    # 플레이어 수 확인
    screen -S minecraft -p 0 -X eval 'stuff "list\015"'
    sleep 2
    
    PLAYER_COUNT=$(tail -20 logs/latest.log | grep -E "There are [0-9]+ of a max" | tail -1 | grep -oE "[0-9]+" | head -1)
    
    if [ -z "$PLAYER_COUNT" ] || [ "$PLAYER_COUNT" -eq 0 ]; then
        COUNTER=$((COUNTER + CHECK_INTERVAL))
        echo "$(date): No players. Idle: ${COUNTER}/${IDLE_TIME}s"
        
        if [ $COUNTER -eq 600 ]; then
            screen -S minecraft -p 0 -X eval 'stuff "say §e⚠ Server shutdown in 5 minutes\015"'
        elif [ $COUNTER -eq 840 ]; then
            screen -S minecraft -p 0 -X eval 'stuff "say §c⚠ Server shutdown in 1 minute!\015"'
        elif [ $COUNTER -ge $IDLE_TIME ]; then
            echo "$(date): Shutting down due to inactivity"
            screen -S minecraft -p 0 -X eval 'stuff "say §c🛑 Shutting down due to inactivity\015"'
            sleep 5
            screen -S minecraft -p 0 -X eval 'stuff "stop\015"'
            sleep 30
            sudo systemctl poweroff
            exit 0
        fi
    else
        if [ $COUNTER -gt 0 ]; then
            echo "$(date): Players online. Resetting counter."
        fi
        COUNTER=0
    fi
done
EOF

chmod +x auto_shutdown.sh

# 서버 관리 스크립트 생성
cat > server_control.sh << 'EOF'
#!/bin/bash
# 서버 제어 스크립트

case "$1" in
    start)
        echo "Starting Minecraft server..."
        ./start_screen.sh
        ;;
    stop)
        echo "Stopping Minecraft server..."
        screen -S minecraft -p 0 -X eval 'stuff "stop\015"'
        ;;
    restart)
        echo "Restarting Minecraft server..."
        screen -S minecraft -p 0 -X eval 'stuff "stop\015"'
        sleep 10
        ./start_screen.sh
        ;;
    console)
        echo "Connecting to server console..."
        screen -r minecraft
        ;;
    status)
        if screen -list | grep -q "minecraft"; then
            echo "Server is running"
        else
            echo "Server is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|console|status}"
        ;;
esac
EOF

chmod +x server_control.sh

# 소유권 변경
chown -R ubuntu:ubuntu /home/ubuntu/minecraft

# 방화벽 설정
ufw allow 25565/tcp
ufw --force enable

# systemd 서비스 생성
cat > /etc/systemd/system/minecraft.service << 'EOF'
[Unit]
Description=Paper 1.21.6 Minecraft Server
After=network.target

[Service]
Type=forking
User=ubuntu
WorkingDirectory=/home/ubuntu/minecraft
ExecStart=/home/ubuntu/minecraft/start_screen.sh
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "stop\015"'
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

# 자동 종료 서비스 생성 (선택사항)
cat > /etc/systemd/system/minecraft-autoshutdown.service << 'EOF'
[Unit]
Description=Minecraft Auto Shutdown Monitor
After=minecraft.service
Requires=minecraft.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/minecraft
ExecStart=/home/ubuntu/minecraft/auto_shutdown.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 설치 완료 정보 생성
cat > installation_complete.txt << 'EOF'
=========================================
Paper 1.21.6 Server Installation Complete
=========================================

Connection: [EC2-PUBLIC-IP]:25565

Server Management:
  Start:    ./server_control.sh start
  Stop:     ./server_control.sh stop
  Console:  ./server_control.sh console
  Status:   ./server_control.sh status

Auto Features:
  - Auto-start on boot
  - Auto-shutdown after 15min idle
  - Optimized Paper configuration
  - Screen session management

Directories:
  - Server: /home/ubuntu/minecraft/
  - Plugins: /home/ubuntu/minecraft/plugins/
  - Logs: /home/ubuntu/minecraft/logs/
  - Backups: /home/ubuntu/minecraft/backups/

First Steps:
  1. Get your EC2 public IP
  2. Connect with Minecraft 1.21.6
  3. Use /op <username> for admin

Installation completed at: $(date)
=========================================
EOF

echo "=== Installation Complete ==="
echo "Server will be ready in 2-3 minutes"
echo "Auto-shutdown: 15 minutes after last player leaves"
echo "Check /home/ubuntu/minecraft/installation_complete.txt for details"