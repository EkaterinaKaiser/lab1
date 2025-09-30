#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import psycopg2
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime

# Параметры подключения к базе данных из переменных окружения
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME', 'university'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres')
}

def connect_to_db():
    """Подключение к базе данных"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except psycopg2.Error as e:
        print(f"Ошибка подключения к базе данных: {e}")
        return None

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

def get_queries():
    """Получение списка всех запросов"""
    return [
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

class QueryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.serve_main_page()
        elif self.path == '/api/queries':
            self.serve_queries_api()
        elif self.path.startswith('/api/query/'):
            query_id = self.path.split('/')[-1]
            self.serve_query_editor(query_id)
        else:
            self.send_error(404)
    
    def do_POST(self):
        if self.path == '/api/execute':
            self.execute_custom_query()
        else:
            self.send_error(404)

    def serve_main_page(self):
        """Отображение главной страницы со списком запросов"""
        queries = get_queries()
        
        html_content = f"""
        <!DOCTYPE html>
        <html lang="ru">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SQL Запросы - Университетская база данных</title>
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
                .query-list {{
                    margin: 20px 0;
                }}
                .query-item {{
                    margin: 15px 0;
                    padding: 15px;
                    border: 1px solid #ddd;
                    border-radius: 5px;
                    background-color: #fafafa;
                    cursor: pointer;
                    transition: background-color 0.3s;
                }}
                .query-item:hover {{
                    background-color: #e9ecef;
                }}
                .query-title {{
                    color: #007bff;
                    font-size: 1.2em;
                    font-weight: bold;
                    margin-bottom: 8px;
                }}
                .query-description {{
                    color: #666;
                    font-style: italic;
                    margin-bottom: 10px;
                }}
                .query-actions {{
                    margin-top: 10px;
                }}
                .btn {{
                    background-color: #007bff;
                    color: white;
                    padding: 8px 16px;
                    border: none;
                    border-radius: 4px;
                    cursor: pointer;
                    text-decoration: none;
                    display: inline-block;
                    margin-right: 10px;
                }}
                .btn:hover {{
                    background-color: #0056b3;
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
                <h1>SQL Запросы к Университетской базе данных</h1>
                <p style="text-align: center; color: #666;">Выберите запрос для выполнения и просмотра результатов</p>
                
                <div class="query-list">
        """
        
        for i, query in enumerate(queries, 1):
            html_content += f"""
                    <div class="query-item">
                        <div class="query-title">{i}. {query['title']}</div>
                        <div class="query-description">{query['description']}</div>
                        <div class="query-actions">
                            <a href="/api/query/{i}" class="btn">Редактировать и выполнить</a>
                        </div>
                    </div>
            """
        
        html_content += f"""
                </div>
                
                <div class="timestamp">
                    Обновлено: {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}
                </div>
            </div>
        </body>
        </html>
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html_content.encode('utf-8'))

    def serve_queries_api(self):
        """API для получения списка запросов"""
        queries = get_queries()
        response = {
            "queries": queries,
            "count": len(queries),
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json; charset=utf-8')
        self.end_headers()
        self.wfile.write(json.dumps(response, ensure_ascii=False, indent=2).encode('utf-8'))

    def serve_query_editor(self, query_id):
        """Отображение редактора SQL запроса"""
        try:
            query_index = int(query_id) - 1
            queries = get_queries()
            
            if query_index < 0 or query_index >= len(queries):
                self.send_error(404, "Запрос не найден")
                return
            
            query_info = queries[query_index]
            
            html_content = f"""
            <!DOCTYPE html>
            <html lang="ru">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Редактор SQL - {query_info['title']}</title>
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
                    .sql-editor {{
                        margin: 20px 0;
                    }}
                    .sql-textarea {{
                        width: 100%;
                        height: 200px;
                        font-family: 'Courier New', monospace;
                        font-size: 14px;
                        padding: 15px;
                        border: 1px solid #ddd;
                        border-radius: 4px;
                        resize: vertical;
                        background-color: #f8f9fa;
                    }}
                    .button-group {{
                        margin: 20px 0;
                        text-align: center;
                    }}
                    .btn {{
                        background-color: #007bff;
                        color: white;
                        padding: 12px 24px;
                        border: none;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 16px;
                        margin: 0 10px;
                    }}
                    .btn:hover {{
                        background-color: #0056b3;
                    }}
                    .btn-secondary {{
                        background-color: #6c757d;
                    }}
                    .btn-secondary:hover {{
                        background-color: #545b62;
                    }}
                    .results-section {{
                        margin-top: 30px;
                        padding: 20px;
                        border: 1px solid #ddd;
                        border-radius: 5px;
                        background-color: #f9f9f9;
                        display: none;
                    }}
                    .error-message {{
                        color: #dc3545;
                        background-color: #f8d7da;
                        border: 1px solid #f5c6cb;
                        padding: 10px;
                        border-radius: 4px;
                        margin: 10px 0;
                    }}
                    .success-message {{
                        color: #155724;
                        background-color: #d4edda;
                        border: 1px solid #c3e6cb;
                        padding: 10px;
                        border-radius: 4px;
                        margin: 10px 0;
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
                    .loading {{
                        text-align: center;
                        color: #666;
                        font-style: italic;
                    }}
                </style>
            </head>
            <body>
                <div class="container">
                    <a href="/" class="btn btn-secondary">← Назад к списку запросов</a>
                    <h1>Редактор SQL запроса</h1>
                    
                    <div class="query-section">
                        <div class="query-title">{query_info['title']}</div>
                        <div class="query-description">{query_info['description']}</div>
                        
                        <div class="sql-editor">
                            <label for="sql-query"><strong>SQL запрос:</strong></label>
                            <textarea id="sql-query" class="sql-textarea" placeholder="Введите ваш SQL запрос здесь...">{query_info['sql'].strip()}</textarea>
                        </div>
                        
                        <div class="button-group">
                            <button onclick="executeQuery()" class="btn">Выполнить запрос</button>
                            <button onclick="resetQuery()" class="btn btn-secondary">Сбросить к исходному</button>
                    </div>
                    
                        <div id="results-section" class="results-section">
                            <h3>Результаты запроса:</h3>
                            <div id="results-content"></div>
                        </div>
                    </div>
                </div>
                
                <script>
                    function executeQuery() {{
                        const sqlQuery = document.getElementById('sql-query').value;
                        const resultsSection = document.getElementById('results-section');
                        const resultsContent = document.getElementById('results-content');
                        
                        if (!sqlQuery.trim()) {{
                            alert('Пожалуйста, введите SQL запрос');
                            return;
                        }}
                        
                        // Показать загрузку
                        resultsContent.innerHTML = '<div class="loading">Выполняется запрос...</div>';
                        resultsSection.style.display = 'block';
                        
                        // Отправить запрос на сервер
                        fetch('/api/execute', {{
                            method: 'POST',
                            headers: {{
                                'Content-Type': 'application/json',
                            }},
                            body: JSON.stringify({{
                                query: sqlQuery,
                                query_id: '{query_id}'
                            }})
                        }})
                        .then(response => response.json())
                        .then(data => {{
                            if (data.success) {{
                                resultsContent.innerHTML = data.html;
                            }} else {{
                                resultsContent.innerHTML = '<div class="error-message">Ошибка: ' + data.error + '</div>';
                            }}
                        }})
                        .catch(error => {{
                            resultsContent.innerHTML = '<div class="error-message">Ошибка выполнения запроса: ' + error.message + '</div>';
                        }});
                    }}
                    
                    function resetQuery() {{
                        document.getElementById('sql-query').value = `{query_info['sql'].strip()}`;
                        document.getElementById('results-section').style.display = 'none';
                    }}
                </script>
            </body>
            </html>
            """
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(html_content.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Ошибка загрузки редактора: {str(e)}")
    
    def execute_custom_query(self):
        """Выполнение пользовательского SQL запроса"""
        try:
            # Получение данных из POST запроса
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            
            sql_query = data.get('query', '')
            query_id = data.get('query_id', '')
            
            if not sql_query.strip():
                response = {
                    "success": False,
                    "error": "Пустой SQL запрос"
                }
            else:
                # Подключение к базе данных
                conn = connect_to_db()
                if not conn:
                    response = {
                        "success": False,
                        "error": "Ошибка подключения к базе данных"
                    }
                else:
                    cursor = conn.cursor()
                    results, columns = execute_query(cursor, sql_query, "Пользовательский запрос")
                    
                    # Генерация HTML с результатами
                    results_html = format_results(results, columns)
                    
                    # Получение информации о запросе
                    queries = get_queries()
                    query_index = int(query_id) - 1
                    query_info = queries[query_index] if 0 <= query_index < len(queries) else None
                    
                    html_content = f"""
                    <div class="success-message">
                        Запрос выполнен успешно! Найдено записей: {len(results)}
                    </div>
                    <div>
                        <strong>Выполненный запрос:</strong>
                        <div class="sql-code" style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 4px; padding: 15px; margin: 10px 0; font-family: 'Courier New', monospace; font-size: 0.9em; overflow-x: auto; white-space: pre-wrap;">{sql_query.strip()}</div>
                    </div>
                    <div>
                        <strong>Результаты:</strong>
                        {results_html}
                    </div>
                    <div style="text-align: center; color: #666; font-size: 0.9em; margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd;">
                        Выполнено: {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}
                    </div>
                    """
                    
                    response = {
                        "success": True,
                        "html": html_content
                    }
                    
                    cursor.close()
                    conn.close()
            
            # Отправка ответа
            self.send_response(200)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
            
        except json.JSONDecodeError:
            response = {
                "success": False,
                "error": "Ошибка парсинга JSON данных"
            }
            self.send_response(400)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
            
        except Exception as e:
            response = {
                "success": False,
                "error": f"Ошибка выполнения запроса: {str(e)}"
            }
            self.send_response(500)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))

def run_server(port=8080):
    """Запуск веб-сервера"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, QueryHandler)
    print(f"Веб-сервер запущен на порту {port}")
    print(f"Откройте http://192.168.0.111:{port} в браузере")
    httpd.serve_forever()

if __name__ == "__main__":
    run_server()

