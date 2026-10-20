#!/bin/sh
TMP_DIR="/tmp"
REPO="fildunsky/luci-app-5gmodem"

echo ">>> Ищем .apk для 5gmodem..."

JSON=$(curl -s -L "https://api.github.com/repos/$REPO/releases/latest")
if [ -z "$JSON" ]; then
    echo "Ошибка: нет связи с GitHub"
    exit 1
fi

ALL_LINKS=$(echo "$JSON" | grep -o '"browser_download_url": "[^"]*"' | cut -d'"' -f4)

TARGET_LINK=""

for LINK in $ALL_LINKS; do
    FILENAME=$(basename "$LINK")
    # Просто ищем любое расширение .apk
    case "$FILENAME" in
        *.apk)
            TARGET_LINK="$LINK"
            echo "  [НАЙДЕН] $FILENAME"
            break
            ;;
    esac
done

if [ -z "$TARGET_LINK" ]; then
    echo "ОШИБКА: Не найдено ни одного файла с расширением .apk в релизе!"
    exit 1
fi

FILE_NAME=$(basename "$TARGET_LINK")
FILE_PATH="$TMP_DIR/$FILE_NAME"

echo "[Скачивание] $FILE_NAME..."
wget -q -O "$FILE_PATH" "$TARGET_LINK"

if [ ! -s "$FILE_PATH" ]; then
    echo "Ошибка: файл не скачался"
    exit 1
fi

echo "[Установка] $FILE_NAME..."
apk add --allow-untrusted "$FILE_PATH"

if [ $? -ne 0 ]; then
    echo "Ошибка установки через apk"
    exit 1
fi

echo ""
echo ">>> Готово!"
