#!/bin/bash

set -e

echo "Iniciando MySQL 8.4..."

brew services start mysql@8.4

echo ""
echo "Estado del servicio:"
brew services list | grep mysql