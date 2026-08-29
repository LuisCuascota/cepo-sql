.PHONY: help db-start db-stop db-status db-restart db-import db-backup db-restore

help:
	@echo "Comandos disponibles:"
	@echo "  make db-start    Inicia MySQL 8.4"
	@echo "  make db-stop     Detiene MySQL 8.4"
	@echo "  make db-status   Muestra el estado de MySQL"
	@echo "  make db-restart  Reinicia MySQL 8.4"
	@echo "  make db-import   Crea e importa la base inicial"
	@echo "  make db-backup   Genera un respaldo de la base"
	@echo "  make db-restore  Restaura un respaldo de la base"

db-start:
	./scripts/db-start.sh

db-stop:
	./scripts/db-stop.sh

db-status:
	./scripts/db-status.sh

db-restart:
	./scripts/db-stop.sh
	./scripts/db-start.sh

db-import:
	./scripts/db-import.sh

db-backup:
	./scripts/db-backup.sh

db-restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Uso: make db-restore FILE=backups/archivo.sql.gz.age"; \
		exit 1; \
	fi
	./scripts/db-restore.sh "$(FILE)"