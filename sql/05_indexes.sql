-- sql/05_indexes.sql
-- Indexes for performance

BEGIN;

SET search_path TO food_chain, public;

-- 1) Сотрудники и заведения
CREATE INDEX IF NOT EXISTS idx_restaurant_city
  ON restaurant (city_id);

CREATE INDEX IF NOT EXISTS idx_employee_city_position
  ON employee (city_id, position_id);

CREATE INDEX IF NOT EXISTS idx_employee_active
  ON employee (employee_id)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_employee_restaurant_restaurant
  ON employee_restaurant (restaurant_id);

-- 2) Роли и пользователи
CREATE INDEX IF NOT EXISTS idx_user_role_role
  ON user_role (role_id);

-- 3) Склад и заявки
CREATE INDEX IF NOT EXISTS idx_ingredient_stock_restaurant_ingredient
  ON ingredient_stock (restaurant_id, ingredient_id);

CREATE INDEX IF NOT EXISTS idx_ingredient_request_rest_status_date
  ON ingredient_request (restaurant_id, status, created_at);

CREATE INDEX IF NOT EXISTS idx_ingredient_request_open
  ON ingredient_request (restaurant_id, created_at)
  WHERE status IN ('NEW', 'APPROVED');

-- 4) Меню и составы
CREATE INDEX IF NOT EXISTS idx_dish_restaurant_category
  ON dish (restaurant_id, category_id);

CREATE INDEX IF NOT EXISTS idx_dish_available
  ON dish (restaurant_id, category_id)
  WHERE is_available = TRUE AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_dish_ingredient_ingredient
  ON dish_ingredient (ingredient_id);

-- 5) Столики и заказы
CREATE INDEX IF NOT EXISTS idx_restaurant_table_restaurant
  ON restaurant_table (restaurant_id);

CREATE INDEX IF NOT EXISTS idx_customer_order_rest_status_datetime
  ON customer_order (restaurant_id, status_code, order_datetime);

CREATE INDEX IF NOT EXISTS idx_customer_order_waiter
  ON customer_order (waiter_id);

-- 6) Позиции заказов и отзывы
CREATE INDEX IF NOT EXISTS idx_order_item_order
  ON order_item (order_id);

CREATE INDEX IF NOT EXISTS idx_order_item_dish
  ON order_item (dish_id);

CREATE INDEX IF NOT EXISTS idx_order_feedback_order
  ON order_feedback (order_id);

COMMIT;
