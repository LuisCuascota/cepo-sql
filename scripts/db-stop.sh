#!/bin/bash

set -e

echo "Deteniendo MySQL 8.4..."

brew services stop mysql@8.4

echo ""
echo "Estado del servicio:"
brew services list | grep mysql