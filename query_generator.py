#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import psycopg2
import sys
from datetime import datetime

# Параметры подключения к базе данных
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'university',
    'user': 'postgres',
    'password': 'postgres'
}

def connect_to_db():
    """Подключение к базе данных"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except psycopg2.Error as e:
        print(f"Ошибка подключения к базе данных: {e}")
        sys.exit(1)

def execute_query(cursor, query, description):
    """Выполнение запроса и возврат результатов"""
    try:
        cursor.execute(query)
        results = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return results, columns
    except psycopg2.Error as e:
        print(f"Ошибка выполнения запроса '{description}': {e}")
        return [], []

def format_results(results, columns):
    """Форматирование результатов для HTML"""
    if not results:
        return "<p>Нет данных</p>"
    
    html = "<table border='1' style='border-collapse: collapse; width: 100%;'>\n"
    html += "<tr>"
    for col in columns:
        html += f"<th style='padding: 8px; background-color: #f2f2f2;'>{col}</th>"
    html += "</tr>\n"
    
    for row in results:
        html += "<tr>"
        for cell in row:
            html += f"<td style='padding: 8px;'>{cell}</td>"
        html += "</tr>\n"
    
    html += "</table>"
    return html

def generate_html():
    """Генерация HTML страницы с результатами запросов"""
    
    # Определение всех запросов
    queries = [
        {
            "title": "Список студентов с указанием их учебных групп и факультетов",
            "description": "Запрос объединяет таблицы students, groups и faculties для отображения полной информации о студентах",
            "sql": """
                SELECT 
                    s.id,
                    s.full_name as "ФИО студента",
                    g.group_name as "Группа",
                    f.faculty_name as "Факультет"
                FROM students s
                JOIN groups g ON s.group_id = g.id
                JOIN faculties f ON g.faculty_id = f.id
                ORDER BY s.id
                LIMIT 20;
            """
        },
        {
            "title": "Все курсы и количество студентов, записанных на каждый из них",
            "description": "Запрос подсчитывает количество записей в таблице enrollments для каждого курса",
            "sql": """
                SELECT 
                    c.course_name as "Название курса",
                    c.credits as "Кредиты",
                    COUNT(e.student_id) as "Количество студентов"
                FROM courses c
                LEFT JOIN enrollments e ON c.id = e.course_id
                GROUP BY c.id, c.course_name, c.credits
                ORDER BY COUNT(e.student_id) DESC;
            """
        },
        {
            "title": "Список студентов, у которых средний балл выше 4.0",
            "description": "Запрос вычисляет средний балл для каждого студента и фильтрует тех, у кого он выше 4.0",
            "sql": """
                SELECT 
                    s.full_name as "ФИО студента",
                    g.group_name as "Группа",
                    ROUND(AVG(e.grade), 2) as "Средний балл"
                FROM students s
                JOIN groups g ON s.group_id = g.id
                JOIN enrollments e ON s.id = e.student_id
                GROUP BY s.id, s.full_name, g.group_name
                HAVING AVG(e.grade) > 4.0
                ORDER BY AVG(e.grade) DESC;
            """
        },
        {
            "title": "Курсы, которые читаются более чем одним преподавателем",
            "description": "Запрос группирует записи преподавания по курсам и находит те, где больше одного преподавателя",
            "sql": """
                SELECT 
                    c.course_name as "Название курса",
                    COUNT(DISTINCT t.lecturer_id) as "Количество преподавателей"
                FROM courses c
                JOIN teaching t ON c.id = t.course_id
                GROUP BY c.id, c.course_name
                HAVING COUNT(DISTINCT t.lecturer_id) > 1
                ORDER BY COUNT(DISTINCT t.lecturer_id) DESC;
            """
        },
        {
            "title": "Список факультетов и количество студентов в каждом из них",
            "description": "Запрос подсчитывает количество студентов через таблицы groups и students",
            "sql": """
                SELECT 
                    f.faculty_name as "Название факультета",
                    COUNT(s.id) as "Количество студентов"
                FROM faculties f
                LEFT JOIN groups g ON f.id = g.faculty_id
                LEFT JOIN students s ON g.id = s.group_id
                GROUP BY f.id, f.faculty_name
                ORDER BY COUNT(s.id) DESC;
            """
        },
        {
            "title": "Студенты, не записанные ни на один курс",
            "description": "Запрос находит студентов, у которых нет записей в таблице enrollments",
            "sql": """
                SELECT 
                    s.id,
                    s.full_name as "ФИО студента",
                    g.group_name as "Группа"
                FROM students s
                JOIN groups g ON s.group_id = g.id
                LEFT JOIN enrollments e ON s.id = e.student_id
                WHERE e.student_id IS NULL
                ORDER BY s.id;
            """
        },
        {
            "title": "Список преподавателей и количества различных курсов, которые они ведут",
            "description": "Запрос подсчитывает количество уникальных курсов для каждого преподавателя",
            "sql": """
                SELECT 
                    l.full_name as "ФИО преподавателя",
                    l.department as "Кафедра",
                    COUNT(DISTINCT t.course_id) as "Количество курсов"
                FROM lecturers l
                LEFT JOIN teaching t ON l.id = t.lecturer_id
                GROUP BY l.id, l.full_name, l.department
                ORDER BY COUNT(DISTINCT t.course_id) DESC;
            """
        },
        {
            "title": "Студенты, имеющие одинаковые оценки по одному и тому же курсу",
            "description": "Запрос находит студентов с одинаковыми оценками по одному курсу, используя оконные функции",
            "sql": """
                WITH grade_groups AS (
                    SELECT 
                        s.full_name as "ФИО студента",
                        c.course_name as "Название курса",
                        e.grade as "Оценка",
                        COUNT(*) OVER (PARTITION BY e.course_id, e.grade) as "Количество с такой же оценкой"
                    FROM students s
                    JOIN enrollments e ON s.id = e.student_id
                    JOIN courses c ON e.course_id = c.id
                )
                SELECT 
                    "ФИО студента",
                    "Название курса",
                    "Оценка",
                    "Количество с такой же оценкой"
                FROM grade_groups
                WHERE "Количество с такой же оценкой" > 1
                ORDER BY "Название курса", "Оценка", "ФИО студента";
            """
        },
        {
            "title": "Курсы, которые не имеют записанных студентов",
            "description": "Запрос находит курсы, у которых нет записей в таблице enrollments",
            "sql": """
                SELECT 
                    c.id,
                    c.course_name as "Название курса",
                    c.credits as "Кредиты"
                FROM courses c
                LEFT JOIN enrollments e ON c.id = e.course_id
                WHERE e.course_id IS NULL
                ORDER BY c.id;
            """
        },
        {
            "title": "Студенты, зачисленные в один и тот же год, с указанием их групп",
            "description": "Запрос группирует студентов по году поступления и показывает их группы",
            "sql": """
                SELECT 
                    s.enrollment_year as "Год поступления",
                    g.group_name as "Группа",
                    COUNT(s.id) as "Количество студентов"
                FROM students s
                JOIN groups g ON s.group_id = g.id
                GROUP BY s.enrollment_year, g.id, g.group_name
                ORDER BY s.enrollment_year, g.group_name;
            """
        },
        {
            "title": "Курсы с указанием суммарного количества кредитов по факультетам",
            "description": "Запрос объединяет курсы с группами и факультетами для подсчета кредитов",
            "sql": """
                SELECT 
                    f.faculty_name as "Факультет",
                    COUNT(DISTINCT c.id) as "Количество курсов",
                    SUM(c.credits) as "Суммарные кредиты"
                FROM faculties f
                JOIN groups g ON f.id = g.faculty_id
                JOIN students s ON g.id = s.group_id
                JOIN enrollments e ON s.id = e.student_id
                JOIN courses c ON e.course_id = c.id
                GROUP BY f.id, f.faculty_name
                ORDER BY SUM(c.credits) DESC;
            """
        },
        {
            "title": "Студенты, имеющие наивысшую оценку по каждому курсу",
            "description": "Запрос находит максимальную оценку по каждому курсу и студентов с такими оценками",
            "sql": """
                WITH max_grades AS (
                    SELECT 
                        course_id,
                        MAX(grade) as max_grade
                    FROM enrollments
                    GROUP BY course_id
                )
                SELECT 
                    c.course_name as "Название курса",
                    s.full_name as "ФИО студента",
                    e.grade as "Оценка"
                FROM enrollments e
                JOIN courses c ON e.course_id = c.id
                JOIN students s ON e.student_id = s.id
                JOIN max_grades mg ON e.course_id = mg.course_id AND e.grade = mg.max_grade
                ORDER BY c.course_name, s.full_name;
            """
        },
        {
            "title": "Преподаватели и студенты, связанные через курсы",
            "description": "Запрос показывает связи между преподавателями и студентами через курсы",
            "sql": """
                SELECT DISTINCT
                    l.full_name as "Преподаватель",
                    l.department as "Кафедра",
                    c.course_name as "Курс",
                    s.full_name as "Студент",
                    g.group_name as "Группа студента"
                FROM lecturers l
                JOIN teaching t ON l.id = t.lecturer_id
                JOIN courses c ON t.course_id = c.id
                JOIN enrollments e ON c.id = e.course_id
                JOIN students s ON e.student_id = s.id
                JOIN groups g ON s.group_id = g.id
                ORDER BY l.full_name, c.course_name, s.full_name
                LIMIT 30;
            """
        },
        {
            "title": "Оценки студентов по курсам в хронологическом порядке с следующей оценкой",
            "description": "Запрос использует оконные функции для отображения текущей и следующей оценки студента",
            "sql": """
                SELECT 
                    s.full_name as "ФИО студента",
                    c.course_name as "Курс",
                    e.grade as "Текущая оценка",
                    LEAD(e.grade) OVER (PARTITION BY s.id ORDER BY e.id) as "Следующая оценка"
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                JOIN courses c ON e.course_id = c.id
                ORDER BY s.id, e.id
                LIMIT 30;
            """
        },
        {
            "title": "Студенты с указанием их места в рейтинге по среднему баллу внутри группы",
            "description": "Запрос вычисляет рейтинг студентов по среднему баллу внутри каждой группы",
            "sql": """
                WITH student_avg_grades AS (
                    SELECT 
                        s.id,
                        s.full_name,
                        g.group_name,
                        AVG(e.grade) as avg_grade
                    FROM students s
                    JOIN groups g ON s.group_id = g.id
                    JOIN enrollments e ON s.id = e.student_id
                    GROUP BY s.id, s.full_name, g.group_name
                )
                SELECT 
                    "ФИО студента",
                    "Группа",
                    ROUND(avg_grade, 2) as "Средний балл",
                    RANK() OVER (PARTITION BY "Группа" ORDER BY avg_grade DESC) as "Место в рейтинге"
                FROM student_avg_grades
                ORDER BY "Группа", "Место в рейтинге";
            """
        }
    ]
    
    # Подключение к базе данных
    conn = connect_to_db()
    cursor = conn.cursor()
    
    # Генерация HTML
    html_content = f"""
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Результаты SQL запросов - Университетская база данных</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                margin: 20px;
                background-color: #f5f5f5;
            }}
            .container {{
                max-width: 1200px;
                margin: 0 auto;
                background-color: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }}
            h1 {{
                color: #333;
                text-align: center;
                border-bottom: 3px solid #007bff;
                padding-bottom: 10px;
            }}
            .query-section {{
                margin: 30px 0;
                padding: 20px;
                border: 1px solid #ddd;
                border-radius: 5px;
                background-color: #fafafa;
            }}
            .query-title {{
                color: #007bff;
                font-size: 1.3em;
                font-weight: bold;
                margin-bottom: 10px;
            }}
            .query-description {{
                color: #666;
                font-style: italic;
                margin-bottom: 15px;
                padding: 10px;
                background-color: #e9ecef;
                border-left: 4px solid #007bff;
            }}
            .sql-code {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 4px;
                padding: 15px;
                margin: 10px 0;
                font-family: 'Courier New', monospace;
                font-size: 0.9em;
                overflow-x: auto;
                white-space: pre-wrap;
            }}
            table {{
                width: 100%;
                border-collapse: collapse;
                margin-top: 15px;
            }}
            th, td {{
                padding: 8px;
                text-align: left;
                border: 1px solid #ddd;
            }}
            th {{
                background-color: #f2f2f2;
                font-weight: bold;
            }}
            tr:nth-child(even) {{
                background-color: #f9f9f9;
            }}
            .timestamp {{
                text-align: center;
                color: #666;
                font-size: 0.9em;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #ddd;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Результаты SQL запросов</h1>
            <p style="text-align: center; color: #666;">Университетская база данных PostgreSQL</p>
    """
    
    # Выполнение каждого запроса
    for i, query_info in enumerate(queries, 1):
        print(f"Выполнение запроса {i}/{len(queries)}: {query_info['title']}")
        
        results, columns = execute_query(cursor, query_info['sql'], query_info['title'])
        results_html = format_results(results, columns)
        
        html_content += f"""
            <div class="query-section">
                <div class="query-title">{i}. {query_info['title']}</div>
                <div class="query-description">{query_info['description']}</div>
                <div class="sql-code">{query_info['sql'].strip()}</div>
                <div>
                    <strong>Результаты ({len(results)} записей):</strong>
                    {results_html}
                </div>
            </div>
        """
    
    html_content += f"""
            <div class="timestamp">
                Сгенерировано: {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}
            </div>
        </div>
    </body>
    </html>
    """
    
    # Сохранение HTML файла
    with open('query_results.html', 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    # Закрытие соединения
    cursor.close()
    conn.close()
    
    print(f"\nHTML файл 'query_results.html' успешно создан!")
    print(f"Выполнено {len(queries)} запросов.")

if __name__ == "__main__":
    generate_html()
