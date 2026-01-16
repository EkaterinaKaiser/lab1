.PHONY: all fetch generate test deploy clean status update-sources enable-pt
SURICATA_CONFIG ?= suricata.yaml

all: fetch generate test deploy status

update-sources:
	@echo "[*] Updating suricata-update sources index..."
	@sudo suricata-update update-sources

enable-pt:
	@echo "[*] Enabling Positive Technologies rules..."
	@sudo suricata-update enable-source pt/open || \
		echo "[!] PT rules source not found. Check available sources with: suricata-update list-sources"

fetch:
	@echo "[*] Stage 1/5: Fetching external IoC feeds..."
	@chmod +x fetch_feeds.sh
	@./fetch_feeds.sh

generate:
	@echo "[*] Stage 2/5: Generating custom_ioc.rules..."
	@chmod +x generate_custom_ioc_rules.py
	@python3 generate_custom_ioc_rules.py

test:
	@echo "[*] Stage 3/5: Testing Suricata configuration..."
	@if [ -f /etc/suricata/suricata.yaml ]; then \
		sudo suricata -T -c /etc/suricata/suricata.yaml; \
	else \
		suricata -T -c $(SURICATA_CONFIG); \
	fi

deploy:
	@echo "[*] Stage 4/5: Deploying rules (reload Suricata)..."
	@if command -v systemctl >/dev/null 2>&1 && sudo systemctl is-active --quiet suricata 2>/dev/null; then \
		sudo systemctl reload suricata || sudo systemctl restart suricata; \
		echo "[+] Pipeline completed successfully!"; \
	else \
		echo "[!] Suricata service not running. Restart manually to apply changes."; \
	fi

status:
	@echo "[*] Stage 5/5: Checking Suricata status..."
	@if command -v systemctl >/dev/null 2>&1; then \
		sudo systemctl status suricata --no-pager | head -10 || echo "[!] Suricata service not found"; \
	else \
		echo "[!] systemctl not available"; \
	fi

clean:
	@echo "[*] Cleaning feeds directory..."
	@rm -rf feeds/
	@echo "[*] Cleaning generated rules..."
	@rm -f rules/custom_ioc.rules