#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Скрипт для автоматического выполнения SQL запросов и генерации HTML страницы
Требует установленного PostgreSQL и Python с psycopg2
"""

import subprocess
import sys
import os

def check_docker():
    """Проверка доступности Docker"""
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

def check_docker_compose():
    """Проверка доступности Docker Compose"""
    try:
        result = subprocess.run(['docker', 'compose', '--version'], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

def start_database():
    """Запуск базы данных через Docker"""
    print("Запуск PostgreSQL контейнера...")
    try:
        subprocess.run(['docker', 'compose', 'up', '-d'], check=True)
        print("База данных запущена успешно!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Ошибка запуска базы данных: {e}")
        return False

def install_requirements():
    """Установка Python зависимостей"""
    print("Установка Python зависимостей...")
    try:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '-r', 'requirements.txt'], check=True)
        print("Зависимости установлены успешно!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Ошибка установки зависимостей: {e}")
        return False

def run_query_generator():
    """Запуск генератора запросов"""
    print("Выполнение SQL запросов и генерация HTML...")
    try:
        subprocess.run([sys.executable, 'query_generator.py'], check=True)
        print("HTML страница сгенерирована успешно!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Ошибка выполнения запросов: {e}")
        return False

def main():
    """Основная функция"""
    print("=== Генератор результатов SQL запросов ===\n")
    
    # Проверка Docker
    if not check_docker():
        print("❌ Docker не найден. Установите Docker для запуска PostgreSQL.")
        print("Альтернативно, используйте файл queries.sql для ручного выполнения запросов.")
        return
    
    if not check_docker_compose():
        print("❌ Docker Compose не найден. Установите Docker Compose.")
        return
    
    # Установка зависимостей
    if not install_requirements():
        print("❌ Не удалось установить зависимости.")
        return
    
    # Запуск базы данных
    if not start_database():
        print("❌ Не удалось запустить базу данных.")
        return
    
    # Ожидание готовности базы данных
    print("Ожидание готовности базы данных...")
    import time
    time.sleep(5)
    
    # Выполнение запросов
    if not run_query_generator():
        print("❌ Не удалось выполнить запросы.")
        return
    
    print("\n✅ Готово! Откройте файл query_results.html в браузере.")
    print("Для остановки базы данных выполните: docker compose down")

if __name__ == "__main__":
    main()
