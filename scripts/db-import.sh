#!/bin/bash

set -e

DB_NAME="caja_ahorro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SQL_FILE="$PROJECT_ROOT/database/init/caja.sql"

echo "Base de datos: $DB_NAME"
echo "Archivo inicial: $SQL_FILE"
echo ""

# Verificar que exista el archivo SQL
if [ ! -f "$SQL_FILE" ]; then
    echo "❌ Error: no existe el archivo:"
    echo "$SQL_FILE"
    exit 1
fi

echo "Verificando estado actual de la base..."

TABLE_COUNT=$(mysql -u root -p -N -s -e "
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = '$DB_NAME';
")

# Si ya existen tablas, abortar
if [ "$TABLE_COUNT" -gt 0 ]; then
    echo ""
    echo "❌ Importación cancelada."
    echo "La base '$DB_NAME' ya contiene $TABLE_COUNT tablas."
    echo ""
    echo "Este comando está diseñado únicamente para una instalación inicial."
    exit 1
fi

echo ""
echo "La base está vacía o todavía no existe."
echo "Creando base de datos..."

mysql -u root -p -e "
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;
"

echo ""
echo "Importando estructura y datos..."

mysql -u root -p "$DB_NAME" < "$SQL_FILE"

echo ""
echo "✅ Importación completada correctamente."