#!/usr/bin/env python3
"""
Генерация custom_ioc.rules из IoC-источников
"""
from pathlib import Path
from datetime import datetime
import sys
import ipaddress

# Конфигурация диапазонов SID для разных источников
SOURCES = {
    "feodo": {
        "file": "feodo_ips.txt",
        "base_sid": 9000000,
        "msg_prefix": "[IPS] Feodo Tracker C&C",
        "classtype": "trojan-activity"
    },
    "urlhaus": {
        "file": "urlhaus_ips.txt",
        "base_sid": 9100000,
        "msg_prefix": "[IPS] URLhaus Malicious IP",
        "classtype": "trojan-activity"
    },
    "botvrij": {
        "file": "botvrij_ips.txt",
        "base_sid": 9200000,
        "msg_prefix": "[IPS] Botvrij.eu IoC",
        "classtype": "trojan-activity"
    },
    # Публичные сервисы (Cloud Providers)
    "google_cloud": {
        "file": "google_cloud_ips.txt",
        "base_sid": 9300000,
        "msg_prefix": "[IPS] Google Cloud IP",
        "classtype": "policy-violation"
    },
    "aws": {
        "file": "aws_ips.txt",
        "base_sid": 9400000,
        "msg_prefix": "[IPS] AWS IP",
        "classtype": "policy-violation"
    },
    "azure": {
        "file": "azure_ips.txt",
        "base_sid": 9500000,
        "msg_prefix": "[IPS] Azure IP",
        "classtype": "policy-violation"
    },
    "cloudflare": {
        "file": "cloudflare_ips.txt",
        "base_sid": 9600000,
        "msg_prefix": "[IPS] Cloudflare IP",
        "classtype": "policy-violation"
    },
    "digitalocean": {
        "file": "digitalocean_ips.txt",
        "base_sid": 9700000,
        "msg_prefix": "[IPS] DigitalOcean IP",
        "classtype": "policy-violation"
    },
    # Ресурсы, запрещенные в РФ
    "antifilter": {
        "file": "antifilter_ips.txt",
        "base_sid": 9800000,
        "msg_prefix": "[IPS] Antifilter (RKN blocked)",
        "classtype": "policy-violation"
    },
    "zapret": {
        "file": "zapret_ips.txt",
        "base_sid": 9900000,
        "msg_prefix": "[IPS] Zapret-info (RKN blocked)",
        "classtype": "policy-violation"
    },
    "rublacklist": {
        "file": "rublacklist_ips.txt",
        "base_sid": 9910000,
        "msg_prefix": "[IPS] Роскомсвобода (RKN blocked)",
        "classtype": "policy-violation"
    }
}


def load_ips(path: Path):
    """Загрузка IP-адресов и CIDR из текстового файла"""
    ips = set()
    if not path.exists():
        print(f"[!] WARNING: File {path} not found, skipping...")
        return list(ips)

    with path.open() as f:
        for line_num, line in enumerate(f, start=1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Извлекаем IP или CIDR: поддерживаем CSV и простой список
            ip_raw = line.split(',')[0].split()[0] if ',' in line or ' ' in line else line

            # Пропускаем строки, которые явно не являются IP (содержат числа > 255)
            if '.' in ip_raw:
                parts = ip_raw.split('.')
                if len(parts) == 4:
                    try:
                        # Проверяем, что все части числа <= 255
                        if any(int(p) > 255 for p in parts if p.isdigit()):
                            continue
                    except (ValueError, AttributeError):
                        pass
            
            try:
                # Пробуем как IPv4 адрес
                ip_obj = ipaddress.IPv4Address(ip_raw)
                ips.add(str(ip_obj))
            except ipaddress.AddressValueError:
                try:
                    # Пробуем как CIDR
                    network = ipaddress.IPv4Network(ip_raw, strict=False)
                    # Дополнительная проверка: все октеты должны быть <= 255
                    if '/' in ip_raw:
                        ip_part = ip_raw.split('/')[0]
                        if '.' in ip_part:
                            parts = ip_part.split('.')
                            if len(parts) == 4 and all(p.isdigit() and int(p) <= 255 for p in parts):
                                ips.add(str(network))
                            else:
                                continue
                        else:
                            ips.add(str(network))
                    else:
                        ips.add(str(network))
                except (ipaddress.AddressValueError, ValueError):
                    # Не логируем каждую ошибку, чтобы не засорять вывод
                    continue

    return list(ips)


def generate_drop_rules(source_name, config, ips):
    """Генерация drop-правил для списка IP/CIDR
    Блокируем трафик ОТ заблокированных IP к HOME_NET
    (для блокировки вредоносных источников)
    НО: не блокируем трафик ОТ HOME_NET (внутренние контейнеры)
    """
    rules = []
    sid = config["base_sid"]
    max_rules = 1000  # Ограничение для предотвращения перегрузки

    for ip_or_cidr in ips[:max_rules]:
        # Блокируем трафик ОТ заблокированных IP к HOME_NET
        # Это блокирует вредоносные источники от доступа к нашей сети
        # Правила pass для HOME_NET обрабатываются первыми, поэтому внутренний трафик не блокируется
        rule = (
            f'drop ip {ip_or_cidr} any -> $HOME_NET any '
            f'(msg:"{config["msg_prefix"]} {ip_or_cidr} -> HOME_NET"; '
            f'classtype:{config["classtype"]}; '
            f'sid:{sid}; rev:1;)\n'
        )
        rules.append(rule)
        sid += 1

    return rules, sid


def add_to_yaml_config(rules_file: Path):
    """Добавление custom_ioc.rules в suricata.yaml, если его там нет"""
    # Пробуем найти suricata.yaml в разных местах
    script_dir = Path(__file__).parent
    yaml_file = None
    
    # 1. В текущей директории (для локальной разработки)
    local_yaml = script_dir / "suricata.yaml"
    if local_yaml.exists():
        yaml_file = local_yaml
    # 2. В /etc/suricata/suricata.yaml (для production)
    elif Path("/etc/suricata/suricata.yaml").exists():
        yaml_file = Path("/etc/suricata/suricata.yaml")
    
    if yaml_file is None:
        print(f"[!] WARNING: suricata.yaml not found. Cannot update config.")
        print(f"[!] You may need to manually add {rules_file.name} to suricata.yaml")
        return

    with yaml_file.open() as f:
        content = f.read()

    rule_filename = rules_file.name
    if rule_filename in content:
        print(f"[*] {rule_filename} already included in suricata.yaml")
        return

    lines = content.splitlines()
    new_lines = []
    inside_rule_files = False
    rule_files_indent = None

    for line in lines:
        new_lines.append(line)
        if line.strip().startswith("rule-files:"):
            inside_rule_files = True
            continue

        if inside_rule_files and line.strip().startswith("- "):
            rule_files_indent = len(line) - len(line.lstrip())
            continue

        # Останавливаемся, как только вышли из секции rule-files
        if inside_rule_files and line and not line.startswith(" ") and not line.startswith("#"):
            # Вставляем перед выходом из секции
            if rule_files_indent is not None:
                new_lines.insert(-1, " " * rule_files_indent + f"- {rule_filename}")
            else:
                # fallback: отступ 4 пробела
                new_lines.insert(-1, "    - " + rule_filename)
            inside_rule_files = False

    # Если секция rule-files есть, но без элементов — добавим в неё
    if inside_rule_files:
        indent = rule_files_indent if rule_files_indent is not None else 4
        new_lines.append(" " * indent + f"- {rule_filename}")

    with yaml_file.open("w") as f:
        f.write("\n".join(new_lines) + "\n")

    print(f"[+] Added {rule_filename} to {yaml_file}")


def main():
    # Определяем путь к feeds относительно скрипта
    script_dir = Path(__file__).parent
    feeds_dir = script_dir / "feeds"
    
    # Создаем директорию feeds если её нет
    feeds_dir.mkdir(parents=True, exist_ok=True)
    
    # Для системы используем /etc/suricata/rules, иначе локальный путь
    if Path("/etc/suricata/rules").exists():
        out_file = Path("/etc/suricata/rules/custom_ioc.rules")
    else:
        # Для локальной разработки или Docker
        rules_dir = script_dir / "rules"
        rules_dir.mkdir(parents=True, exist_ok=True)
        out_file = rules_dir / "custom_ioc.rules"

    all_rules = []
    stats = {}

    print("[*] Starting IoC rules generation...\n")

    for source_name, config in SOURCES.items():
        source_file = feeds_dir / config["file"]
        ips = load_ips(source_file)
        if not ips:
            stats[source_name] = 0
            print(f"[!] {source_name.upper()}: No valid IPs loaded")
            continue

        rules, last_sid = generate_drop_rules(source_name, config, ips)
        all_rules.extend(rules)
        stats[source_name] = len(rules)
        print(f"[+] {source_name.upper()}: Generated {len(rules)} rules "
              f"(SID: {config['base_sid']}-{last_sid - 1})")

    if not all_rules:
        print("\n[!] ERROR: No rules generated. Check if feeds were downloaded correctly.")
        print("[!] Run ./fetch_feeds.sh first to download IoC feeds.")
        sys.exit(1)

    # Убедимся, что директория существует
    out_file.parent.mkdir(parents=True, exist_ok=True)

    with out_file.open("w") as f:
        f.write(f"# Autogenerated IoC-based rules from multiple sources\n")
        f.write(f"# Generated: {datetime.now().isoformat()}\n")
        f.write(f"# Total rules: {len(all_rules)}\n")
        f.write(f"# Sources: {', '.join(SOURCES.keys())}\n")
        f.write(f"#\n")
        for source, count in stats.items():
            f.write(f"# - {source}: {count} rules\n")
        f.write(f"\n")
        
        # Добавляем разрешающие правила для HTTP/HTTPS в начало (высокий приоритет)
        # Эти правила должны быть ПЕРЕД блокирующими правилами drop
        # В Suricata правила обрабатываются по порядку, pass останавливает дальнейшую проверку
        f.write("# ============================================\n")
        f.write("# ALLOW RULES (HIGH PRIORITY - PROCESSED FIRST)\n")
        f.write("# ============================================\n")
        f.write("# Allow HTTP/HTTPS traffic to HOME_NET from any source\n")
        f.write("pass http any any -> $HOME_NET any (msg:\"Allow HTTP traffic to HOME_NET\"; sid:8000001; rev:1;)\n")
        f.write("pass tcp any any -> $HOME_NET 80 (msg:\"Allow HTTP on port 80\"; sid:8000002; rev:1;)\n")
        f.write("pass tcp any any -> $HOME_NET 443 (msg:\"Allow HTTPS on port 443\"; sid:8000003; rev:1;)\n")
        f.write("# Allow TCP traffic to HOME_NET (for HTTP and other services)\n")
        f.write("pass tcp any any -> $HOME_NET any (msg:\"Allow TCP traffic to HOME_NET\"; sid:8000005; rev:1;)\n")
        f.write("# Allow UDP traffic to HOME_NET (for DNS and other services)\n")
        f.write("pass udp any any -> $HOME_NET any (msg:\"Allow UDP traffic to HOME_NET\"; sid:8000006; rev:1;)\n")
        f.write("# NOTE: ICMP is NOT allowed here - it should be blocked by custom.rules\n")
        f.write("\n")
        f.write("# ============================================\n")
        f.write("# BLOCKING RULES (IoC-based, processed after allow rules)\n")
        f.write("# ============================================\n")
        f.write("\n")
        f.writelines(all_rules)

    print(f"\n[+] Total: Generated {len(all_rules)} rules into {out_file}")

    # Добавляем в конфиг Suricata
    add_to_yaml_config(out_file)

    print("\n[*] Done! Restart or reload Suricata to apply changes.")
    print("[*] Example: sudo systemctl reload suricata")


if __name__ == "__main__":
    main()
