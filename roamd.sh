#!/bin/sh
TMP_DIR="/tmp"
REPO="teuchezh/roamd"

# Получаем архитектуру
if [ -f /etc/openwrt_release ]; then
    ARCH=$(grep "^DISTRIB_ARCH=" /etc/openwrt_release | head -n 1 | sed "s/DISTRIB_ARCH='//" | sed "s/'$//")
else
    echo "Ошибка: нет /etc/openwrt_release"
    exit 1
fi

if [ -z "$ARCH" ]; then
    echo "Ошибка: не удалось определить архитектуру"
    exit 1
fi
echo ">>> Архитектура: $ARCH"

# Получаем ссылки
JSON=$(curl -s -L "https://api.github.com/repos/$REPO/releases/latest")
if [ -z "$JSON" ]; then
    echo "Ошибка: нет связи с GitHub"
    exit 1
fi
ALL_LINKS=$(echo "$JSON" | grep -o '"browser_download_url": "[^"]*"' | cut -d'"' -f4)

BASE_LINK=""
LUCI_LINK=""
I18N_LINK=""

echo ">>> Поиск пакетов..."

for LINK in $ALL_LINKS; do
    FILENAME=$(basename "$LINK")
    
    # Проверка: это apk?
    case "$FILENAME" in
        *.apk) ;;
        *) continue ;;
    esac
    
    # Проверка: есть ли наша архитектура в имени?
    if ! echo "$FILENAME" | grep -q "$ARCH"; then
        continue
    fi
    
    # Проверка: не вариация ли это (mipsel_24kc_...)
    if echo "$FILENAME" | grep -q "${ARCH}_[[:alnum:]]"; then
        continue
    fi

    # ГЛАВНОЕ: Чёткое распределение по строкам. 
    # Сначала проверяем точные совпадения, потом общее.
    
    if [ "$FILENAME" = "25.12-${ARCH}-luci-app-roamd-1.3.0-r1.apk" ]; then
        LUCI_LINK="$LINK"
        echo "  [НАЙДЕН] LUCI: $FILENAME"
    elif [ "$FILENAME" = "25.12-${ARCH}-luci-i18n-roamd-ru-1.3.0-r1.apk" ]; then
        I18N_LINK="$LINK"
        echo "  [НАЙДЕН] I18N: $FILENAME"
    elif [ "$FILENAME" = "25.12-${ARCH}-roamd-1.3.0-r1.apk" ]; then
        BASE_LINK="$LINK"
        echo "  [НАЙДЕН] BASE: $FILENAME"
    fi
done

if [ -z "$BASE_LINK" ]; then
    echo "КРИТИЧЕСКАЯ ОШИБКА: Базовый пакет не найден!"
    exit 1
fi

echo ""
echo ">>> Установка..."

install_pkg() {
    local link=$1
    local name=$(basename "$link")
    local path="$TMP_DIR/$name"
    
    echo "[Скачивание] $name..."
    wget -q -O "$path" "$link"
    
    if [ ! -s "$path" ]; then
        echo "ОШИБКА: Файл $name не скачался."
        exit 1
    fi
    
    echo "[Установка] $name..."
    apk add --allow-untrusted "$path"
    if [ $? -ne 0 ]; then
        echo "ОШИБКА установки $name."
        exit 1
    fi
}

install_pkg "$BASE_LINK"

if [ -n "$LUCI_LINK" ]; then
    install_pkg "$LUCI_LINK"
else
    echo "ВНИМАНИЕ: luci-app НЕ найден."
fi

if [ -n "$I18N_LINK" ]; then
    install_pkg "$I18N_LINK"
else
    echo "ВНИМАНИЕ: i18n НЕ найден."
fi

echo ""
echo ">>> Готово!"
