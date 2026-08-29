#!/bin/bash

set -e

DB_NAME="caja_ahorro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Debes indicar el archivo de backup."
    echo ""
    echo "Uso:"
    echo "  make db-restore FILE=backups/archivo.sql.gz.age"
    exit 1
fi

# Convertir ruta relativa a absoluta
if [[ "$BACKUP_FILE" != /* ]]; then
    BACKUP_FILE="$PROJECT_ROOT/$BACKUP_FILE"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ No existe el archivo:"
    echo "$BACKUP_FILE"
    exit 1
fi

# Archivo temporal para la restauración
TEMP_SQL=$(mktemp /tmp/caja_restore_XXXXXX.sql)

# Siempre borrar el temporal al terminar
cleanup() {
    rm -f "$TEMP_SQL"
}

trap cleanup EXIT

echo ""
echo "Backup seleccionado:"
echo "  $BACKUP_FILE"
echo ""

echo "🔐 Descifrando backup..."
echo "Ingresa la contraseña de cifrado de age."
echo ""

# Primero desciframos completamente.
# NO tocamos MySQL todavía.
if ! age --decrypt "$BACKUP_FILE" | gunzip > "$TEMP_SQL"; then
    echo ""
    echo "❌ No se pudo descifrar o descomprimir el backup."
    echo "La base de datos NO fue modificada."
    exit 1
fi

# Verificar que el SQL realmente tenga contenido
if [ ! -s "$TEMP_SQL" ]; then
    echo "❌ El backup descifrado está vacío."
    exit 1
fi

echo ""
echo "✅ Backup descifrado correctamente."
echo ""

echo "⚠️  ATENCIÓN"
echo "Esto reemplazará completamente la base:"
echo ""
echo "  $DB_NAME"
echo ""

read -r -p "Escribe RESTAURAR para continuar: " CONFIRMATION

if [ "$CONFIRMATION" != "RESTAURAR" ]; then
    echo ""
    echo "Restauración cancelada."
    exit 0
fi

echo ""
echo "Eliminando base actual..."
echo "Ingresa la contraseña de MySQL."
echo ""

mysql -u root -p -e "
DROP DATABASE IF EXISTS \`$DB_NAME\`;
"

echo ""
echo "Restaurando backup..."
echo "Ingresa nuevamente la contraseña de MySQL."
echo ""

mysql -u root -p < "$TEMP_SQL"

echo ""
echo "✅ Restauración completada correctamente."
echo ""

echo "Verificando base restaurada..."
echo "Ingresa la contraseña de MySQL."
echo ""

mysql -u root -p -e "
SELECT
    table_schema AS base_datos,
    COUNT(*) AS tablas
FROM information_schema.tables
WHERE table_schema = '$DB_NAME'
GROUP BY table_schema;
"