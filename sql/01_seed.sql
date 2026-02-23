-- sql/01_seed.sql
-- Test data for food_chain

BEGIN;

SET search_path TO food_chain, public;

-- 1) city
INSERT INTO city (name, region) VALUES
('Москва', 'Московская область'),
('Санкт-Петербург', 'Ленинградская область')
ON CONFLICT (name) DO NOTHING;

-- 2) position
INSERT INTO position (name, description) VALUES
('Администратор зала', 'Контроль работы зала и персонала'),
('Менеджер', 'Управление заведением и сменами'),
('Аналитик', 'Аналитика продаж и эффективности'),
('Повар', 'Приготовление блюд'),
('Официант', 'Обслуживание гостей')
ON CONFLICT (name) DO NOTHING;

-- 3) dish_category
INSERT INTO dish_category (name, description) VALUES
('Закуски', 'Лёгкие блюда перед основными'),
('Супы', 'Первые блюда'),
('Горячие блюда', 'Основные горячие блюда'),
('Десерты', 'Сладкие блюда'),
('Напитки', 'Чай, кофе, соки и др.')
ON CONFLICT (name) DO NOTHING;

-- 4) order_status
INSERT INTO order_status (status_code, name, description) VALUES
('NEW', 'Новый', 'Заказ создан'),
('IN_PROGRESS', 'Готовится', 'Заказ в работе'),
('READY', 'Готов', 'Заказ готов к выдаче'),
('PAID', 'Оплачен', 'Заказ закрыт и оплачен'),
('CANCELLED', 'Отменён', 'Заказ отменён')
ON CONFLICT (status_code) DO NOTHING;

-- 5) role
INSERT INTO role (code, name, description) VALUES
('admin', 'Администратор', 'Полный доступ к системе'),
('analyst', 'Аналитик', 'Доступ к отчётам и аналитике'),
('manager', 'Менеджер', 'Управление заведением и персоналом'),
('cook', 'Повар', 'Работа со складом и заявками, кухня'),
('waiter', 'Официант', 'Работа с заказами гостей')
ON CONFLICT (code) DO NOTHING;

-- 6) ingredient
INSERT INTO ingredient (name, unit, description) VALUES
('Куриное филе', 'кг', 'Охлаждённое'),
('Картофель', 'кг', 'Мытый'),
('Помидоры', 'кг', 'Свежие'),
('Сыр моцарелла', 'кг', 'Для горячих блюд'),
('Мука', 'кг', 'Пшеничная'),
('Сливки', 'л', '20%'),
('Кофе', 'г', 'Зёрна/молотый'),
('Сахар', 'кг', 'Белый')
ON CONFLICT (name) DO NOTHING;

-- 7) supplier
INSERT INTO supplier (name, phone, email, address) VALUES
('ООО ФудПоставка', '+7-495-111-11-11', 'sales@foodpostavka.ru', 'Москва, ул. Примерная, 1'),
('ИП Петров', '+7-812-222-22-22', 'petrov@suppliers.ru', 'Санкт-Петербург, Невский пр., 10'),
('ООО СладСнаб', '+7-495-333-33-33', 'info@sladsnab.ru', 'Москва, ул. Кондитерская, 5')
ON CONFLICT (name) DO NOTHING;

-- 8) restaurant (3 заведения)
INSERT INTO restaurant
(city_id, name, type, address, postal_code, phone, employees_count, seats_count, opening_time, closing_time)
VALUES
((SELECT city_id FROM city WHERE name='Москва'), 'Город', 'Ресторан', 'Москва, Тверская, 10', '125000', '+7-495-000-00-01', 15, 60, '09:00', '23:00'),
((SELECT city_id FROM city WHERE name='Москва'), 'Токио', 'Суши-бар', 'Москва, Арбат, 5', '119002', '+7-495-000-00-02', 10, 30, '10:00', '22:00'),
((SELECT city_id FROM city WHERE name='Санкт-Петербург'), 'Сладкий дом', 'Кондитерская', 'СПб, Литейный, 7', '191028', '+7-812-000-00-03', 8, 25, '08:00', '21:00')
ON CONFLICT (city_id, name) DO NOTHING;

-- 9) employee (несколько менеджеров/поваров/официант)
INSERT INTO employee
(city_id, position_id, last_name, first_name, middle_name, phone, email, hire_date, experience_years, salary, birth_date, short_info, is_active)
VALUES
-- Москва
((SELECT city_id FROM city WHERE name='Москва'),
 (SELECT position_id FROM position WHERE name='Менеджер'),
 'Иванов','Иван','Иванович', '+7-495-100-00-01','ivanov@food.local','2022-03-01', 5, 120000, '1995-05-12', 'Менеджер смены', TRUE),

((SELECT city_id FROM city WHERE name='Москва'),
 (SELECT position_id FROM position WHERE name='Повар'),
 'Петров','Пётр','Петрович', '+7-495-100-00-02','petrov@food.local','2021-06-15', 7, 110000, '1990-11-20', 'Повар универсал', TRUE),

((SELECT city_id FROM city WHERE name='Москва'),
 (SELECT position_id FROM position WHERE name='Официант'),
 'Сидорова','Анна','Сергеевна', '+7-495-100-00-03','sidorova@food.local','2023-02-10', 2, 70000, '2000-02-03', 'Официант зала', TRUE),

-- Санкт-Петербург
((SELECT city_id FROM city WHERE name='Санкт-Петербург'),
 (SELECT position_id FROM position WHERE name='Менеджер'),
 'Кузнецов','Дмитрий','Алексеевич', '+7-812-200-00-01','kuznetsov@food.local','2020-09-01', 8, 130000, '1988-07-08', 'Менеджер заведения', TRUE),

((SELECT city_id FROM city WHERE name='Санкт-Петербург'),
 (SELECT position_id FROM position WHERE name='Повар'),
 'Смирнова','Ольга','Игоревна', '+7-812-200-00-02','smirnova@food.local','2022-01-20', 4, 100000, '1996-03-30', 'Кондитер/повар', TRUE)
ON CONFLICT DO NOTHING;

-- 10) employee_restaurant (Петров закреплён за двумя заведениями)
INSERT INTO employee_restaurant (employee_id, restaurant_id, is_primary)
VALUES
-- Иванов (Менеджер) -> Город (основное)
((SELECT e.employee_id FROM employee e WHERE e.last_name='Иванов' AND e.first_name='Иван'),
 (SELECT r.restaurant_id FROM restaurant r WHERE r.name='Город'), TRUE),

-- Петров (Повар) -> Город (основное)
((SELECT e.employee_id FROM employee e WHERE e.last_name='Петров' AND e.first_name='Пётр'),
 (SELECT r.restaurant_id FROM restaurant r WHERE r.name='Город'), TRUE),

-- Петров (Повар) -> Токио (доп.)
((SELECT e.employee_id FROM employee e WHERE e.last_name='Петров' AND e.first_name='Пётр'),
 (SELECT r.restaurant_id FROM restaurant r WHERE r.name='Токио'), FALSE),

-- Сидорова (Официант) -> Город
((SELECT e.employee_id FROM employee e WHERE e.last_name='Сидорова' AND e.first_name='Анна'),
 (SELECT r.restaurant_id FROM restaurant r WHERE r.name='Город'), TRUE),

-- Кузнецов (Менеджер) -> Сладкий дом
((SELECT e.employee_id FROM employee e WHERE e.last_name='Кузнецов' AND e.first_name='Дмитрий'),
 (SELECT r.restaurant_id FROM restaurant r WHERE r.name='Сладкий дом'), TRUE),

-- Смирнова (Повар) -> Сладкий дом
((SELECT e.employee_id FROM employee e WHERE e.last_name='Смирнова' AND e.first_name='Ольга'),
 (SELECT r.restaurant_id FROM restaurant r WHERE r.name='Сладкий дом'), TRUE)
ON CONFLICT (employee_id, restaurant_id) DO NOTHING;

-- 11) app_user (учётки сотрудников)
INSERT INTO app_user (employee_id, login, password_hash, is_active)
VALUES
((SELECT employee_id FROM employee WHERE last_name='Иванов' AND first_name='Иван'), 'ivanov', 'hash_ivanov', TRUE),
((SELECT employee_id FROM employee WHERE last_name='Петров' AND first_name='Пётр'), 'petrov', 'hash_petrov', TRUE),
((SELECT employee_id FROM employee WHERE last_name='Сидорова' AND first_name='Анна'), 'sidorova', 'hash_sidorova', TRUE),
((SELECT employee_id FROM employee WHERE last_name='Кузнецов' AND first_name='Дмитрий'), 'kuznetsov', 'hash_kuznetsov', TRUE),
((SELECT employee_id FROM employee WHERE last_name='Смирнова' AND first_name='Ольга'), 'smirnova', 'hash_smirnova', TRUE)
ON CONFLICT (login) DO NOTHING;

-- 12) user_role (Иванов: admin + manager)
INSERT INTO user_role (user_id, role_id)
VALUES
-- Иванов: admin, manager
((SELECT user_id FROM app_user WHERE login='ivanov'), (SELECT role_id FROM role WHERE code='admin')),
((SELECT user_id FROM app_user WHERE login='ivanov'), (SELECT role_id FROM role WHERE code='manager')),

-- Петров: cook
((SELECT user_id FROM app_user WHERE login='petrov'), (SELECT role_id FROM role WHERE code='cook')),

-- Сидорова: waiter
((SELECT user_id FROM app_user WHERE login='sidorova'), (SELECT role_id FROM role WHERE code='waiter')),

-- Кузнецов: manager
((SELECT user_id FROM app_user WHERE login='kuznetsov'), (SELECT role_id FROM role WHERE code='manager')),

-- Смирнова: cook
((SELECT user_id FROM app_user WHERE login='smirnova'), (SELECT role_id FROM role WHERE code='cook'))
ON CONFLICT (user_id, role_id) DO NOTHING;

-- 13) ingredient_stock (остатки по заведениям)
INSERT INTO ingredient_stock
(restaurant_id, ingredient_id, supplier_id, quantity, unit_price, received_date, expiry_date)
VALUES
-- Город
((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT ingredient_id FROM ingredient WHERE name='Куриное филе'),
 (SELECT supplier_id FROM supplier WHERE name='ООО ФудПоставка'),
 25.000, 420.00, '2026-02-01', '2026-02-10'),

((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT ingredient_id FROM ingredient WHERE name='Картофель'),
 (SELECT supplier_id FROM supplier WHERE name='ООО ФудПоставка'),
 60.000, 45.00, '2026-02-01', '2026-03-01'),

((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT ingredient_id FROM ingredient WHERE name='Помидоры'),
 (SELECT supplier_id FROM supplier WHERE name='ООО ФудПоставка'),
 30.000, 180.00, '2026-02-02', '2026-02-09'),

-- Токио
((SELECT restaurant_id FROM restaurant WHERE name='Токио'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сыр моцарелла'),
 (SELECT supplier_id FROM supplier WHERE name='ООО ФудПоставка'),
 12.000, 650.00, '2026-02-03', '2026-02-20'),

-- Сладкий дом
((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT ingredient_id FROM ingredient WHERE name='Мука'),
 (SELECT supplier_id FROM supplier WHERE name='ООО СладСнаб'),
 40.000, 55.00, '2026-02-01', '2026-06-01'),

((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сливки'),
 (SELECT supplier_id FROM supplier WHERE name='ООО СладСнаб'),
 20.000, 210.00, '2026-02-01', '2026-02-15'),

((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT ingredient_id FROM ingredient WHERE name='Кофе'),
 (SELECT supplier_id FROM supplier WHERE name='ИП Петров'),
 3000.000, 1.50, '2026-02-01', '2026-12-31'),

((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сахар'),
 (SELECT supplier_id FROM supplier WHERE name='ООО СладСнаб'),
 25.000, 80.00, '2026-02-01', '2026-08-01');

-- 14) ingredient_request (заявки поваров)
INSERT INTO ingredient_request
(restaurant_id, employee_id, ingredient_id, quantity, status, created_at, processed_at, manager_comment)
VALUES
-- Помидоры для "Город" (автор Петров)
((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT employee_id FROM employee WHERE last_name='Петров' AND first_name='Пётр'),
 (SELECT ingredient_id FROM ingredient WHERE name='Помидоры'),
 10.000, 'NEW', now() - interval '2 days', NULL, NULL),

-- Сливки для "Сладкий дом" (автор Смирнова)
((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT employee_id FROM employee WHERE last_name='Смирнова' AND first_name='Ольга'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сливки'),
 8.000, 'NEW', now() - interval '1 day', NULL, NULL);

-- 15) dish (блюда по заведениям)
INSERT INTO dish
(restaurant_id, category_id, name, price, cook_time_min, is_available, is_deleted)
VALUES
-- Город: горячее + суп
((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT category_id FROM dish_category WHERE name='Горячие блюда'),
 'Куриное филе с картофелем', 590.00, 25, TRUE, FALSE),

((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT category_id FROM dish_category WHERE name='Супы'),
 'Сливочный суп с курицей', 420.00, 20, TRUE, FALSE),

-- Токио: роллы (категория можно считать "Закуски" для примера)
((SELECT restaurant_id FROM restaurant WHERE name='Токио'),
 (SELECT category_id FROM dish_category WHERE name='Закуски'),
 'Ролл Калифорния', 520.00, 15, TRUE, FALSE),

-- Сладкий дом: торт + кофе
((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT category_id FROM dish_category WHERE name='Десерты'),
 'Торт Наполеон', 360.00, 10, TRUE, FALSE),

((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT category_id FROM dish_category WHERE name='Напитки'),
 'Капучино', 190.00, 5, TRUE, FALSE)
ON CONFLICT (restaurant_id, name) DO NOTHING;

-- 16) dish_ingredient (состав блюд)
INSERT INTO dish_ingredient (dish_id, ingredient_id, quantity)
VALUES
-- Куриное филе с картофелем
((SELECT dish_id FROM dish WHERE name='Куриное филе с картофелем'),
 (SELECT ingredient_id FROM ingredient WHERE name='Куриное филе'),
 0.200),

((SELECT dish_id FROM dish WHERE name='Куриное филе с картофелем'),
 (SELECT ingredient_id FROM ingredient WHERE name='Картофель'),
 0.250),

((SELECT dish_id FROM dish WHERE name='Куриное филе с картофелем'),
 (SELECT ingredient_id FROM ingredient WHERE name='Помидоры'),
 0.100),

-- Сливочный суп с курицей
((SELECT dish_id FROM dish WHERE name='Сливочный суп с курицей'),
 (SELECT ingredient_id FROM ingredient WHERE name='Куриное филе'),
 0.150),

((SELECT dish_id FROM dish WHERE name='Сливочный суп с курицей'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сливки'),
 0.200),

-- Торт Наполеон
((SELECT dish_id FROM dish WHERE name='Торт Наполеон'),
 (SELECT ingredient_id FROM ingredient WHERE name='Мука'),
 0.120),

((SELECT dish_id FROM dish WHERE name='Торт Наполеон'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сливки'),
 0.080),

((SELECT dish_id FROM dish WHERE name='Торт Наполеон'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сахар'),
 0.050),

-- Капучино
((SELECT dish_id FROM dish WHERE name='Капучино'),
 (SELECT ingredient_id FROM ingredient WHERE name='Кофе'),
 18.000),

((SELECT dish_id FROM dish WHERE name='Капучино'),
 (SELECT ingredient_id FROM ingredient WHERE name='Сахар'),
 0.010)
ON CONFLICT (dish_id, ingredient_id) DO NOTHING;

-- 17) restaurant_table (столики)
INSERT INTO restaurant_table (restaurant_id, table_number, seats, is_active)
VALUES
-- Город
((SELECT restaurant_id FROM restaurant WHERE name='Город'), '1', 4, TRUE),
((SELECT restaurant_id FROM restaurant WHERE name='Город'), '2', 2, TRUE),
((SELECT restaurant_id FROM restaurant WHERE name='Город'), '3', 6, TRUE),

-- Токио
((SELECT restaurant_id FROM restaurant WHERE name='Токио'), 'A1', 2, TRUE),
((SELECT restaurant_id FROM restaurant WHERE name='Токио'), 'A2', 4, TRUE),

-- Сладкий дом
((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'), '10', 2, TRUE),
((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'), '11', 4, TRUE)
ON CONFLICT (restaurant_id, table_number) DO NOTHING;

-- 18) customer_order (2 заказа)
INSERT INTO customer_order
(restaurant_id, table_id, waiter_id, order_datetime, status_code, guests_count, special_requests, total_amount)
VALUES
-- Заказ в "Город" (официант Сидорова)
((SELECT restaurant_id FROM restaurant WHERE name='Город'),
 (SELECT table_id FROM restaurant_table WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Город') AND table_number='1'),
 (SELECT employee_id FROM employee WHERE last_name='Сидорова' AND first_name='Анна'),
 now() - interval '3 hours',
 'IN_PROGRESS',
 2,
 'Без лука',
 1010.00),

-- Заказ в "Сладкий дом" (официант — можно NULL, если не задан официант в кондитерской)
((SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом'),
 (SELECT table_id FROM restaurant_table WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом') AND table_number='10'),
 NULL,
 now() - interval '1 hours',
 'PAID',
 1,
 NULL,
 740.00);

-- 19) order_item (позиции заказов)
INSERT INTO order_item (order_id, dish_id, quantity, unit_price, comment)
VALUES
-- заказ 1 ("Город"): 1 горячее + 1 суп
((SELECT order_id FROM customer_order
  WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Город')
  ORDER BY order_datetime DESC LIMIT 1),
 (SELECT dish_id FROM dish WHERE name='Куриное филе с картофелем'),
 1, 590.00, NULL),

((SELECT order_id FROM customer_order
  WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Город')
  ORDER BY order_datetime DESC LIMIT 1),
 (SELECT dish_id FROM dish WHERE name='Сливочный суп с курицей'),
 1, 420.00, 'Без сухариков'),

-- заказ 2 ("Сладкий дом"): 1 торт + 2 капучино
((SELECT order_id FROM customer_order
  WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом')
  ORDER BY order_datetime DESC LIMIT 1),
 (SELECT dish_id FROM dish WHERE name='Торт Наполеон'),
 1, 360.00, NULL),

((SELECT order_id FROM customer_order
  WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом')
  ORDER BY order_datetime DESC LIMIT 1),
 (SELECT dish_id FROM dish WHERE name='Капучино'),
 2, 190.00, 'Один без сахара');

-- 20) order_feedback (отзывы по двум заказам)
INSERT INTO order_feedback (order_id, rating, comment, created_at, would_recommend)
VALUES
((SELECT order_id FROM customer_order
  WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Город')
  ORDER BY order_datetime DESC LIMIT 1),
 5, 'Отличное обслуживание и вкусная еда', now() - interval '2 hours', TRUE),

((SELECT order_id FROM customer_order
  WHERE restaurant_id=(SELECT restaurant_id FROM restaurant WHERE name='Сладкий дом')
  ORDER BY order_datetime DESC LIMIT 1),
 4, 'Хороший кофе, торт понравился', now() - interval '30 minutes', TRUE)
ON CONFLICT (order_id) DO NOTHING;

COMMIT;
