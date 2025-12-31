#!/usr/bin/env python3
"""
Генерация custom_ioc.rules из IoC-источников
"""
from pathlib import Path
from datetime import datetime
import sys
import ipaddress  # ← Используем для валидации IP

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
    }
}

def load_ips(path: Path):
    """Загрузка IP-адресов из текстового файла"""
    ips = set()  # ← Используем set, чтобы избежать дубликатов
    if not path.exists():
        print(f"[!] WARNING: File {path} not found, skipping...")
        return ips

    with path.open() as f:
        for line_num, line in enumerate(f, start=1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Извлекаем IP: поддерживаем CSV и простой список
            ip_raw = line.split(',')[0].split()[0] if ',' in line or ' ' in line else line

            try:
                ip_obj = ipaddress.IPv4Address(ip_raw)
                ips.add(str(ip_obj))
            except ipaddress.AddressValueError:
                print(f"[!] WARNING: Invalid IP '{ip_raw}' in {path}:{line_num}, skipping")
                continue

    return list(ips)  # ← Возвращаем список, но без дубликатов


def generate_drop_rules(source_name, config, ips):
    """Генерация drop-правил для списка IP"""
    rules = []
    sid = config["base_sid"]
    max_rules = 1000  # Ограничение для предотвращения перегрузки

    for ip in ips[:max_rules]:
        rule = (
            f'drop ip {ip} any -> $HOME_NET any '
            f'(msg:"{config["msg_prefix"]} {ip}"; '
            f'classtype:{config["classtype"]}; '
            f'sid:{sid}; rev:1;)\n'
        )
        rules.append(rule)
        sid += 1

    return rules, sid


def add_to_yaml_config(rules_file: Path):
    """Добавление custom_ioc.rules в suricata.yaml, если его там нет"""
    yaml_file = Path("/etc/suricata/suricata.yaml")

    if not yaml_file.exists():
        print(f"[!] ERROR: {yaml_file} not found. Cannot update config.")
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
            # Найдём отступ для элементов списка
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
    feeds_dir = Path(__file__).parent / "feeds"
    out_file = Path("/etc/suricata/rules/custom_ioc.rules")

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
        f.writelines(all_rules)

    print(f"\n[+] Total: Generated {len(all_rules)} rules into {out_file}")

    # Добавляем в конфиг Suricata
    add_to_yaml_config(out_file)

    print("\n[*] Done! Restart or reload Suricata to apply changes.")
    print("[*] Example: sudo systemctl reload suricata")


if __name__ == "__main__":
    main()