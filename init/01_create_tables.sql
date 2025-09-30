-- Создание таблиц для университетской базы данных

-- Создание таблицы факультетов
CREATE TABLE faculties (
    id SERIAL PRIMARY KEY,
    faculty_name VARCHAR(100) NOT NULL
);

-- Создание таблицы групп
CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    group_name VARCHAR(50) NOT NULL,
    faculty_id INTEGER REFERENCES faculties(id)
);

-- Создание таблицы студентов
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    group_id INTEGER REFERENCES groups(id),
    enrollment_year INTEGER NOT NULL
);

-- Создание таблицы курсов
CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    credits INTEGER NOT NULL
);

-- Создание таблицы преподавателей
CREATE TABLE lecturers (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL
);

-- Создание таблицы записей о зачислении на курсы
CREATE TABLE enrollments (
    id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES students(id),
    course_id INTEGER REFERENCES courses(id),
    grade INTEGER CHECK (grade >= 1 AND grade <= 5)
);

-- Создание таблицы преподавания
CREATE TABLE teaching (
    id SERIAL PRIMARY KEY,
    lecturer_id INTEGER REFERENCES lecturers(id),
    course_id INTEGER REFERENCES courses(id),
    semester VARCHAR(20) NOT NULL
);

-- Создание индексов для улучшения производительности
CREATE INDEX idx_students_group_id ON students(group_id);
CREATE INDEX idx_groups_faculty_id ON groups(faculty_id);
CREATE INDEX idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX idx_enrollments_course_id ON enrollments(course_id);
CREATE INDEX idx_teaching_lecturer_id ON teaching(lecturer_id);
CREATE INDEX idx_teaching_course_id ON teaching(course_id);
