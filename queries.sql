-- SQL запросы для университетской базы данных
-- Выполните эти запросы в PostgreSQL и скопируйте результаты в HTML файл

-- 1. Список студентов с указанием их учебных групп и факультетов
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

-- 2. Все курсы и количество студентов, записанных на каждый из них
SELECT 
    c.course_name as "Название курса",
    c.credits as "Кредиты",
    COUNT(e.student_id) as "Количество студентов"
FROM courses c
LEFT JOIN enrollments e ON c.id = e.course_id
GROUP BY c.id, c.course_name, c.credits
ORDER BY COUNT(e.student_id) DESC;

-- 3. Список студентов, у которых средний балл выше 4.0
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

-- 4. Курсы, которые читаются более чем одним преподавателем
SELECT 
    c.course_name as "Название курса",
    COUNT(DISTINCT t.lecturer_id) as "Количество преподавателей"
FROM courses c
JOIN teaching t ON c.id = t.course_id
GROUP BY c.id, c.course_name
HAVING COUNT(DISTINCT t.lecturer_id) > 1
ORDER BY COUNT(DISTINCT t.lecturer_id) DESC;

-- 5. Список факультетов и количество студентов в каждом из них
SELECT 
    f.faculty_name as "Название факультета",
    COUNT(s.id) as "Количество студентов"
FROM faculties f
LEFT JOIN groups g ON f.id = g.faculty_id
LEFT JOIN students s ON g.id = s.group_id
GROUP BY f.id, f.faculty_name
ORDER BY COUNT(s.id) DESC;

-- 6. Студенты, не записанные ни на один курс
SELECT 
    s.id,
    s.full_name as "ФИО студента",
    g.group_name as "Группа"
FROM students s
JOIN groups g ON s.group_id = g.id
LEFT JOIN enrollments e ON s.id = e.student_id
WHERE e.student_id IS NULL
ORDER BY s.id;

-- 7. Список преподавателей и количества различных курсов, которые они ведут
SELECT 
    l.full_name as "ФИО преподавателя",
    l.department as "Кафедра",
    COUNT(DISTINCT t.course_id) as "Количество курсов"
FROM lecturers l
LEFT JOIN teaching t ON l.id = t.lecturer_id
GROUP BY l.id, l.full_name, l.department
ORDER BY COUNT(DISTINCT t.course_id) DESC;

-- 8. Студенты, имеющие одинаковые оценки по одному и тому же курсу
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

-- 9. Курсы, которые не имеют записанных студентов
SELECT 
    c.id,
    c.course_name as "Название курса",
    c.credits as "Кредиты"
FROM courses c
LEFT JOIN enrollments e ON c.id = e.course_id
WHERE e.course_id IS NULL
ORDER BY c.id;

-- 10. Студенты, зачисленные в один и тот же год, с указанием их групп
SELECT 
    s.enrollment_year as "Год поступления",
    g.group_name as "Группа",
    COUNT(s.id) as "Количество студентов"
FROM students s
JOIN groups g ON s.group_id = g.id
GROUP BY s.enrollment_year, g.id, g.group_name
ORDER BY s.enrollment_year, g.group_name;

-- 11. Курсы с указанием суммарного количества кредитов по факультетам
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

-- 12. Студенты, имеющие наивысшую оценку по каждому курсу
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

-- 13. Преподаватели и студенты, связанные через курсы
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

-- 14. Оценки студентов по курсам в хронологическом порядке с следующей оценкой
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

-- 15. Студенты с указанием их места в рейтинге по среднему баллу внутри группы
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
