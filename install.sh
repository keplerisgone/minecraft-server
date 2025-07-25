#!/bin/bash
# 버전 선택 가능한 Paper 설치 스크립트

exec > >(tee /var/log/minecraft-install.log) 2>&1
echo "=== Paper Minecraft Server Installation ==="
echo "Time: $(date)"

# 버전 선택 함수
select_minecraft_version() {
    echo "🎮 Available Minecraft versions for Paper:"
    echo
    
    # Paper API에서 지원하는 버전 목록 가져오기
    VERSIONS=$(curl -s "https://api.papermc.io/v2/projects/paper/" | jq -r '.versions[]' | tail -10)
    
    if [ -z "$VERSIONS" ]; then
        echo "❌ Failed to fetch versions. Using default 1.21.6"
        MINECRAFT_VERSION="1.21.6"
        return 0
    fi
    
    echo "Recent versions:"
    local i=1
    declare -a version_array
    while IFS= read -r version; do
        echo "$i) $version"
        version_array[$i]="$version"
        ((i++))
    done <<< "$VERSIONS"
    
    echo
    echo "Enter version number (1-$((i-1))) or type version directly (e.g., 1.21.6):"
    read -p "Choice: " choice
    
    # 숫자인지 확인
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        MINECRAFT_VERSION="${version_array[$choice]}"
    else
        MINECRAFT_VERSION="$choice"
    fi
    
    echo "Selected version: $MINECRAFT_VERSION"
}

# 빌드 선택 함수
select_build() {
    echo
    echo "🔨 Fetching available builds for $MINECRAFT_VERSION..."
    
    # 해당 버전의 빌드 목록 가져오기
    BUILDS_JSON=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/")
    
    if [ $? -ne 0 ] || [ -z "$BUILDS_JSON" ]; then
        echo "❌ Failed to fetch builds for version $MINECRAFT_VERSION"
        echo "Please check if the version exists or try again."
        exit 1
    fi
    
    BUILDS=$(echo "$BUILDS_JSON" | jq -r '.builds[]' | tail -5)
    LATEST_BUILD=$(echo "$BUILDS_JSON" | jq -r '.builds[-1]')
    
    echo "Available builds (showing last 5):"
    local i=1
    declare -a build_array
    while IFS= read -r build; do
        echo "$i) Build $build"
        build_array[$i]="$build"
        ((i++))
    done <<< "$BUILDS"
    
    echo "$i) Latest build ($LATEST_BUILD) [Recommended]"
    echo
    read -p "Choose build (1-$i, or press Enter for latest): " build_choice
    
    if [ -z "$build_choice" ] || [ "$build_choice" -eq "$i" ]; then
        BUILD_NUMBER="$LATEST_BUILD"
    elif [[ "$build_choice" =~ ^[0-9]+$ ]] && [ "$build_choice" -ge 1 ] && [ "$build_choice" -lt "$i" ]; then
        BUILD_NUMBER="${build_array[$build_choice]}"
    else
        BUILD_NUMBER="$LATEST_BUILD"
    fi
    
    echo "Selected build: $BUILD_NUMBER"
}

# OS 감지 및 패키지 매니저 설정
if [ -f /etc/debian_version ]; then
    PKG_UPDATE="apt update && apt upgrade -y"
    PKG_INSTALL="apt install -y"
    USER_HOME="/home/ubuntu"
    SERVER_USER="ubuntu"
    OS_TYPE="debian"
elif [ -f /etc/amazon-linux-release ]; then
    PKG_UPDATE="dnf update -y"
    PKG_INSTALL="dnf install -y"
    USER_HOME="/home/ec2-user"
    SERVER_USER="ec2-user"
    OS_TYPE="amazon2023"
elif [ -f /etc/redhat-release ]; then
    PKG_UPDATE="yum update -y"
    PKG_INSTALL="yum install -y"
    USER_HOME="/home/ec2-user"
    SERVER_USER="ec2-user"
    OS_TYPE="amazon2"
else
    echo "Unsupported OS"
    exit 1
fi

echo "Detected OS: $OS_TYPE"
echo "User home: $USER_HOME"

# 인터랙티브 버전 선택 (스크립트 인자로도 가능)
if [ -n "$1" ]; then
    MINECRAFT_VERSION="$1"
    echo "Using provided version: $MINECRAFT_VERSION"
else
    select_minecraft_version
fi

if [ -n "$2" ]; then
    BUILD_NUMBER="$2"
    echo "Using provided build: $BUILD_NUMBER"
else
    select_build
fi

# 시스템 업데이트
echo
echo "=== System Update ==="
$PKG_UPDATE

# 기본 패키지 설치
echo "=== Installing Base Packages ==="
$PKG_INSTALL screen wget unzip curl jq git

# Java 설치 (버전에 따라 다른 Java 버전 사용)
echo "=== Installing Java ==="
MAJOR_VERSION=$(echo "$MINECRAFT_VERSION" | cut -d. -f2)

if [ "$MAJOR_VERSION" -ge 21 ]; then
    JAVA_VERSION="21"
elif [ "$MAJOR_VERSION" -ge 18 ]; then
    JAVA_VERSION="17"
else
    JAVA_VERSION="11"
fi

echo "Installing Java $JAVA_VERSION for Minecraft $MINECRAFT_VERSION"

case $OS_TYPE in
    "debian")
        $PKG_INSTALL "openjdk-${JAVA_VERSION}-jdk"
        export JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"
        ;;
    "amazon2023")
        $PKG_INSTALL "java-${JAVA_VERSION}-amazon-corretto" "java-${JAVA_VERSION}-amazon-corretto-devel"
        export JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-amazon-corretto"
        ;;
    "amazon2")
        wget "https://corretto.aws/downloads/latest/amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.rpm"
        rpm -ivh "amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.rpm"
        rm -f "amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.rpm"
        export JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-amazon-corretto"
        ;;
esac

echo "export JAVA_HOME=$JAVA_HOME" >> $USER_HOME/.bashrc
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> $USER_HOME/.bashrc

java -version

# 서버 디렉토리 생성
echo "=== Creating Server Directories ==="
mkdir -p $USER_HOME/minecraft/{plugins,logs,backups,config}
cd $USER_HOME/minecraft

# Paper 다운로드
echo "=== Downloading Paper $MINECRAFT_VERSION Build $BUILD_NUMBER ==="
DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds/$BUILD_NUMBER/downloads/paper-$MINECRAFT_VERSION-$BUILD_NUMBER.jar"

echo "Download URL: $DOWNLOAD_URL"
wget -O paper.jar "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
    echo "❌ Failed to download Paper. Please check version and build numbers."
    exit 1
fi

echo "✅ Paper $MINECRAFT_VERSION Build $BUILD_NUMBER downloaded successfully"

# EULA 동의
echo "eula=true" > eula.txt

# 메모리 설정 (버전에 따라 조정)
if [ "$MAJOR_VERSION" -ge 21 ]; then
    MEMORY_FLAGS="-Xms2G -Xmx2G"
    JVM_ARGS="--add-modules=jdk.incubator.vector"
elif [ "$MAJOR_VERSION" -ge 18 ]; then
    MEMORY_FLAGS="-Xms1800M -Xmx1800M"
    JVM_ARGS=""
else
    MEMORY_FLAGS="-Xms1500M -Xmx1500M"
    JVM_ARGS=""
fi

# 서버 설정
echo "=== Creating server.properties ==="
cat > server.properties << EOF
server-port=25565
max-players=10
online-mode=true
difficulty=easy
gamemode=survival
motd=§6Paper $MINECRAFT_VERSION Server! §b🎈
view-distance=10
simulation-distance=10
spawn-protection=16
allow-nether=true
generate-structures=true
spawn-monsters=true
spawn-animals=true
white-list=false
enforce-whitelist=false
pvv=true
enable-command-block=true
max-tick-time=60000
network-compression-threshold=256
EOF

# start.sh 생성 (개선된 버전)
echo "=== Creating start.sh ==="
cat > start.sh << EOF
#!/bin/bash
cd $USER_HOME/minecraft
export JAVA_HOME=$JAVA_HOME
export PATH=\$JAVA_HOME/bin:\$PATH

java $MEMORY_FLAGS \\
  -XX:+UseG1GC \\
  -XX:+ParallelRefProcEnabled \\
  -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions \\
  -XX:+DisableExplicitGC \\
  -XX:+AlwaysPreTouch \\
  -XX:G1NewSizePercent=30 \\
  -XX:G1MaxNewSizePercent=40 \\
  -XX:G1HeapRegionSize=8M \\
  -XX:G1ReservePercent=20 \\
  -XX:G1HeapWastePercent=5 \\
  -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 \\
  -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 \\
  -XX:SurvivorRatio=32 \\
  -XX:+PerfDisableSharedMem \\
  -XX:MaxTenuringThreshold=1 \\
  $JVM_ARGS \\
  -jar paper.jar --nogui
EOF
# 실제 사용하는 스크립트들만 생성
echo "=== Creating start_screen.sh ==="
cat > start_screen.sh << EOF
#!/bin/bash
cd $USER_HOME/minecraft
screen -S minecraft -dm bash start.sh
echo "Paper server started in screen session 'minecraft'"
echo "Commands:"
echo "  screen -r minecraft  # Access console"
echo "  Ctrl+A, D          # Detach from console"
EOF
chmod +x start_screen.sh

echo "=== Creating auto_shutdown.sh ==="
cat > auto_shutdown.sh << EOF
#!/bin/bash
IDLE_TIME=600       # 10분
CHECK_INTERVAL=60   # 1분마다 체크
COUNTER=0
SCREEN_NAME="minecraft" # 스크린 이름을 변수로 관리
PID_FILE="$USER_HOME/minecraft/auto_shutdown.pid"
LOG_FILE="$USER_HOME/minecraft/logs/latest.log"  # 마인크래프트 로그 파일

trap 'rm -f "\$PID_FILE"' EXIT

echo "Auto-shutdown monitor started at \$(date)"
echo "Will shutdown after \$IDLE_TIME seconds of no players on screen session '\$SCREEN_NAME'"
echo \$\$ > "\$PID_FILE"

# 현재 온라인 플레이어를 추적하기 위한 배열
declare -A online_players

while true; do
    sleep \$CHECK_INTERVAL
    
    if ! screen -list | grep -q "\$SCREEN_NAME"; then
        echo "\$(date): Server screen session '\$SCREEN_NAME' not found. Monitor stopping."
        exit 0
    fi
    
    # 로그 파일에서 최근 플레이어 접속/종료 정보 읽기
    if [ -f "\$LOG_FILE" ]; then
        # 최근 10분간의 로그만 확인 (성능 최적화)
        recent_logs=\$(tail -n 1000 "\$LOG_FILE" | grep -E "(joined the game|left the game)" | tail -n 50)
        
        # 플레이어 상태 업데이트
        while IFS= read -r line; do
            if [[ \$line =~ \\[.*\\]\\ \\[.*\\]:\\ (.+)\\ joined\\ the\\ game ]]; then
                player="\${BASH_REMATCH[1]}"
                online_players["\$player"]=1
            elif [[ \$line =~ \\[.*\\]\\ \\[.*\\]:\\ (.+)\\ left\\ the\\ game ]]; then
                player="\${BASH_REMATCH[1]}"
                unset online_players["\$player"]
            fi
        done <<< "\$recent_logs"
        
        PLAYER_COUNT=\${#online_players[@]}
    else
        echo "\$(date): Warning - Log file not found: \$LOG_FILE"
        PLAYER_COUNT=0
    fi
    
    if [ "\$PLAYER_COUNT" -eq 0 ]; then
        COUNTER=\$((COUNTER + CHECK_INTERVAL))
        echo "\$(date): No players online. Idle time: \${COUNTER}/\${IDLE_TIME} seconds"
        
        if [ \$COUNTER -ge \$IDLE_TIME ]; then
            echo "\$(date): Idle time exceeded. Shutting down..."
            screen -S "\$SCREEN_NAME" -p 0 -X eval 'stuff "say §c🛑 Server shutting down due to inactivity\\015"'
            sleep 5
            screen -S "\$SCREEN_NAME" -p 0 -X eval 'stuff "stop\\015"'
            sleep 30
            sudo systemctl poweroff
            exit 0
        fi
    else
        if [ \$COUNTER -gt 0 ]; then
            echo "\$(date): Players online (\$PLAYER_COUNT). Resetting idle counter."
        else
            # 매번 현재 상태를 로깅 (디버깅용)
            echo "\$(date): Check completed - \$PLAYER_COUNT players online"
        fi
        echo "\$(date): Online players: \${!online_players[*]}"
        COUNTER=0
    fi
    
    # 추가 디버깅 정보
    echo "\$(date): Player detection method: Log file analysis"
done
EOF
chmod +x auto_shutdown.sh

echo "=== Creating autoshutdown_control.sh ==="
cat > autoshutdown_control.sh << EOF
#!/bin/bash

PID_FILE="$USER_HOME/minecraft/auto_shutdown.pid"
LOG_FILE="$USER_HOME/minecraft/auto_shutdown.log"

case "\$1" in
    start)
        if [ -f "\$PID_FILE" ] && kill -0 \$(cat \$PID_FILE) 2>/dev/null; then
            echo "Auto-shutdown is already running (PID: \$(cat \$PID_FILE))"
        else
            cd $USER_HOME/minecraft
            nohup ./auto_shutdown.sh > \$LOG_FILE 2>&1 &
            echo \$! > \$PID_FILE
            echo "✅ Auto-shutdown started (PID: \$(cat \$PID_FILE))"
        fi
        ;;
    stop)
        if [ -f "\$PID_FILE" ]; then
            PID=\$(cat \$PID_FILE)
            if kill \$PID 2>/dev/null; then
                echo "✅ Auto-shutdown stopped (PID: \$PID)"
                rm -f \$PID_FILE
            else
                echo "❌ Failed to stop auto-shutdown"
            fi
        else
            echo "❌ Auto-shutdown is not running"
        fi
        ;;
    status)
        if [ -f "\$PID_FILE" ]; then
            PID=\$(cat \$PID_FILE)
            if kill -0 \$PID 2>/dev/null; then
                echo "✅ Auto-shutdown is running (PID: \$PID)"
                echo "📊 Recent activity:"
                tail -5 \$LOG_FILE 2>/dev/null || echo "No log available"
            else
                echo "❌ Auto-shutdown PID file exists but process is dead"
                rm -f \$PID_FILE
            fi
        else
            echo "❌ Auto-shutdown is not running"
        fi
        ;;
    log)
        if [ -f "\$LOG_FILE" ]; then
            echo "📝 Auto-shutdown log (last 20 lines):"
            tail -20 \$LOG_FILE
        else
            echo "❌ No log file found"
        fi
        ;;
    restart)
        \$0 stop
        sleep 2
        \$0 start
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|log}"
        echo
        echo "Commands:"
        echo "  start   - Start auto-shutdown monitoring"
        echo "  stop    - Stop auto-shutdown monitoring"
        echo "  restart - Restart auto-shutdown monitoring"
        echo "  status  - Check auto-shutdown status"
        echo "  log     - Show recent auto-shutdown log"
        ;;
esac
EOF
chmod +x autoshutdown_control.sh

echo "=== Creating server_manager.sh ==="
cat > server_manager.sh << EOF
#!/bin/bash

SERVER_DIR="$USER_HOME/minecraft"
cd \$SERVER_DIR

show_status() {
    echo "=== Minecraft Server Manager ==="
    echo "Time: \$(date)"
    echo
    
    # 서버 상태
    if screen -ls | grep -q "minecraft"; then
        echo "🎮 Server: ✅ RUNNING"
        if ss -tlpn | grep -q ":25565"; then
            echo "🌐 Port 25565: ✅ LISTENING"
        else
            echo "🌐 Port 25565: ❌ NOT LISTENING"
        fi
    else
        echo "🎮 Server: ❌ STOPPED"
    fi
    
    # 자동종료 상태
    if [ -f "auto_shutdown.pid" ] && kill -0 \$(cat auto_shutdown.pid) 2>/dev/null; then
        echo "⏰ Auto-shutdown: ✅ ACTIVE"
    else
        echo "⏰ Auto-shutdown: ❌ INACTIVE"
    fi
    
    # 시스템 정보
    echo "💻 Memory: \$(free -h | grep Mem | awk '{print \$3"/"\$2}')"
    echo "💿 Disk: \$(df -h \$SERVER_DIR | tail -1 | awk '{print \$5" used"}')"
    echo
}

case "\$1" in
    start)
        echo "🚀 Starting Minecraft server and auto-shutdown..."
        ./start_screen.sh
        sleep 3
        ./autoshutdown_control.sh start
        echo
        show_status
        ;;
    stop)
        echo "🛑 Stopping server and auto-shutdown..."
        screen -S minecraft -p 0 -X eval 'stuff "say §c⚠️ SERVER SHUTTING DOWN IN 5 SECONDS!\015"'
	    sleep 1
	    screen -S minecraft -p 0 -X eval 'stuff "say §e⚠️ 4...\015"'
	    sleep 1
	    screen -S minecraft -p 0 -X eval 'stuff "say §e⚠️ 3...\015"'
    	sleep 1
    	screen -S minecraft -p 0 -X eval 'stuff "say §6⚠️ 2...\015"'
    	sleep 1
    	screen -S minecraft -p 0 -X eval 'stuff "say §c⚠️ 1...\015"'
    	sleep 1
    
    	screen -S minecraft -p 0 -X eval 'stuff "say §4🛑 SERVER STOPPING NOW! Goodbye! §f❤️\015"'
        sleep 1
        ./autoshutdown_control.sh stop
        screen -S minecraft -X eval 'stuff "stop\\015"'
        echo
        show_status
        ;;
    restart)
        echo "🔄 Restarting everything..."
        \$0 stop
        sleep 5
        \$0 start
        ;;
    status)
        show_status
        ;;
    console)
        echo "🖥️ Connecting to server console (Ctrl+A, D to detach)..."
        screen -r minecraft
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|console}"
        echo
        echo "🎮 Minecraft Server Manager"
        echo "  start   - Start server + auto-shutdown"
        echo "  stop    - Stop server + auto-shutdown"
        echo "  restart - Restart everything"
        echo "  status  - Show complete status"
        echo "  console - Access server console"
        ;;
esac
EOF
chmod +x server_manager.sh

# 소유권 변경
chown -R $SERVER_USER:$SERVER_USER $USER_HOME/minecraft

# 방화벽 설정
echo "=== Configuring Firewall ==="
case $OS_TYPE in
    "debian")
        if command -v ufw >/dev/null 2>&1; then
            ufw allow 25565/tcp
            ufw --force enable
        fi
        ;;
    "amazon2023"|"amazon2")
        if command -v firewall-cmd >/dev/null 2>&1; then
            firewall-cmd --permanent --add-port=25565/tcp
            firewall-cmd --reload
        fi
        ;;
esac

# systemd 서비스 생성
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/minecraft.service << EOF
[Unit]
Description=Paper $MINECRAFT_VERSION Minecraft Server
After=network.target

[Service]
Type=forking
User=$SERVER_USER
Group=$SERVER_USER
WorkingDirectory=$USER_HOME/minecraft
ExecStart=$USER_HOME/minecraft/start_screen.sh
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "stop\\015"'
ExecStop=/bin/sleep 15
RemainAfterExit=yes
RestartSec=30
Restart=on-failure
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft.service

# 설치 완료 정보 생성
cat > $USER_HOME/minecraft/installation_info.txt << EOF
========================================
Paper $MINECRAFT_VERSION Installation Complete
========================================
Time: $(date)
Version: Paper $MINECRAFT_VERSION Build $BUILD_NUMBER
Java: $(java -version 2>&1 | head -1)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
User: $SERVER_USER

Connection: [YOUR-EC2-PUBLIC-IP]:25565

Quick Commands:
./server_manager.sh start      # Start everything
./server_manager.sh stop       # Stop everything  
./server_manager.sh status     # Check status
./server_manager.sh console    # Access console

Auto-shutdown: 10 minutes after last player leaves

Files created:
- start.sh (Java server launcher)
- start_screen.sh (Screen session wrapper)  
- auto_shutdown.sh (Auto-shutdown monitor)
- autoshutdown_control.sh (Auto-shutdown control)
- server_manager.sh (Main control script)

Next Steps:
1. Get your EC2 Public IP
2. Open Security Group port 25565
3. Start server: ./server_manager.sh start
4. Connect with Minecraft $MINECRAFT_VERSION client
5. Use /op <username> for admin

========================================
EOF

echo
echo "🎉 Installation completed successfully!"
echo "📋 Server: Paper $MINECRAFT_VERSION Build $BUILD_NUMBER"
echo "☕ Java: $JAVA_VERSION"
echo "📁 Location: $USER_HOME/minecraft"
echo
echo "🚀 Start server: cd $USER_HOME/minecraft && ./server_manager.sh start"
echo "📖 Full info: cat $USER_HOME/minecraft/installation_info.txt"
