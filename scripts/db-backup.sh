#!/bin/bash

set -e

DB_NAME="caja_ahorro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

TEMP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"
ENCRYPTED_FILE="${TEMP_FILE}.age"

mkdir -p "$BACKUP_DIR"

echo "Generando respaldo de '$DB_NAME'..."
echo ""

mysqldump \
  -u root \
  -p \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --databases "$DB_NAME" \
  | gzip > "$TEMP_FILE"

if [ ! -s "$TEMP_FILE" ]; then
    echo "❌ Error: el archivo de respaldo está vacío."
    rm -f "$TEMP_FILE"
    exit 1
fi

echo ""
echo "Cifrando respaldo..."
echo "Define la contraseña de cifrado cuando age la solicite."
echo ""

age \
  --passphrase \
  --output "$ENCRYPTED_FILE" \
  "$TEMP_FILE"

rm -f "$TEMP_FILE"

if [ ! -s "$ENCRYPTED_FILE" ]; then
    echo "❌ Error: no se pudo generar el respaldo cifrado."
    exit 1
fi

echo ""
echo "✅ Backup generado y cifrado correctamente:"
echo "$ENCRYPTED_FILE"

echo ""
echo "Tamaño:"
du -h "$ENCRYPTED_FILE"