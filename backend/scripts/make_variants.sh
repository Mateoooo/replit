#!/bin/sh
# Делает N разных копий учебного архива: в каждую дописывается строка в Gemfile.
# Так Docker не может взять слой bundle install из кеша — как будто у всех студентов разные проекты.
#
# Использование:  scripts/make_variants.sh app.zip 25 [папка_для_результата]
set -e
SRC="$1"
N="${2:-25}"
OUT="${3:-./stress-zips}"
[ -f "$SRC" ] || { echo "Нет файла: $SRC"; exit 1; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
STAMP=$(date +%s)   # новая метка при каждом запуске: сборки гарантированно «холодные», без кеша прошлых тестов

i=1
while [ "$i" -le "$N" ]; do
  TMP=$(mktemp -d)
  unzip -q "$SRC" -d "$TMP"
  ROOT="$TMP"
  if [ ! -f "$TMP/Gemfile" ]; then
    SUB=$(find "$TMP" -mindepth 1 -maxdepth 1 -type d ! -name __MACOSX | head -n 1)
    [ -f "$SUB/Gemfile" ] && ROOT="$SUB"
  fi
  [ -f "$ROOT/Gemfile" ] || { echo "В архиве нет Gemfile"; exit 1; }
  printf '\n# stress variant %s %s\n' "$i" "$STAMP" >> "$ROOT/Gemfile"
  (cd "$TMP" && zip -qr "$OUT/app-$i.zip" .)
  rm -rf "$TMP"
  i=$((i + 1))
done
echo "Готово: $N архивов в $OUT"
