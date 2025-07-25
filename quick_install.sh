#!/bin/bash
# 빠른 Paper 설치 스크립트 (버전 선택)

echo "🎮 Paper Minecraft Server Quick Installer"
echo "=========================================="

# 인기 버전들 미리 정의
declare -A POPULAR_VERSIONS=(
    ["1"]="1.21.6"
    ["2"]="1.21.5" 
    ["3"]="1.21.4"
    ["4"]="1.21.3"
    ["5"]="1.20.6"
    ["6"]="1.20.4"
    ["7"]="1.19.4"
    ["8"]="1.18.2"
)

echo "Popular Minecraft versions:"
echo "1) 1.21.6 (Latest)"
echo "2) 1.21.5"
echo "3) 1.21.4" 
echo "4) 1.21.3"
echo "5) 1.20.6"
echo "6) 1.20.4"
echo "7) 1.19.4"
echo "8) 1.18.2"
echo "9) Custom version"
echo

read -p "Select version (1-9): " choice

case $choice in
    [1-8])
        SELECTED_VERSION=${POPULAR_VERSIONS[$choice]}
        echo "✅ Selected: $SELECTED_VERSION"
        ;;
    9)
        echo "Available versions (from Paper API):"
        curl -s "https://api.papermc.io/v2/projects/paper/" | jq -r '.versions[]' | tail -15 | nl
        echo
        read -p "Enter version (e.g., 1.21.6): " SELECTED_VERSION
        ;;
    *)
        echo "❌ Invalid choice. Using default 1.21.6"
        SELECTED_VERSION="1.21.6"
        ;;
esac

echo
echo "🔨 Installing Paper $SELECTED_VERSION..."
echo "This will take a few minutes..."
echo

# 메인 설치 스크립트 실행 (버전을 인자로 전달)
if [ -f "./complete_install_script.sh" ]; then
    chmod +x ./complete_install_script.sh
    ./complete_install_script.sh "$SELECTED_VERSION"
else
    echo "❌ complete_install_script.sh not found!"
    echo "Please download the complete installation script first."
    exit 1
fi