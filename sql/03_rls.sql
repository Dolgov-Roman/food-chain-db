-- sql/03_rls.sql
-- Row Level Security policies

BEGIN;

SET search_path TO food_chain, public;

-- 1) Вспомогательная функция: текущий employee_id по current_user
-- SECURITY DEFINER: чтобы читать app_user даже если нет прямых прав
CREATE OR REPLACE FUNCTION get_current_employee_id()
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_employee_id BIGINT;
BEGIN
  SELECT au.employee_id
    INTO v_employee_id
  FROM app_user au
  WHERE au.login = current_user
    AND au.is_active = TRUE
  LIMIT 1;

  RETURN v_employee_id;
END;
$$;

-- ограничим право менять владельца/права на функцию (опционально)
REVOKE ALL ON FUNCTION get_current_employee_id() FROM PUBLIC;

-- 2) Включение RLS на основных таблицах
ALTER TABLE customer_order     ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_item         ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_stock   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_request ENABLE ROW LEVEL SECURITY;

FORCE RLS, чтобы даже владелец соблюдал политики
-- ALTER TABLE customer_order     FORCE ROW LEVEL SECURITY;
-- ALTER TABLE order_item         FORCE ROW LEVEL SECURITY;
-- ALTER TABLE ingredient_stock   FORCE ROW LEVEL SECURITY;
-- ALTER TABLE ingredient_request FORCE ROW LEVEL SECURITY;

-- =========================================================
-- 3) customer_order: политики
-- =========================================================

-- Администраторы: полный доступ ко всем строкам
DROP POLICY IF EXISTS customer_order_admin_all ON customer_order;
CREATE POLICY customer_order_admin_all
ON customer_order
FOR ALL
TO app_admins
USING (true)
WITH CHECK (true);

-- Аналитики: чтение всех заказов
DROP POLICY IF EXISTS customer_order_analyst_read ON customer_order;
CREATE POLICY customer_order_analyst_read
ON customer_order
FOR SELECT
TO app_analysts
USING (true);

-- Сотрудники (менеджеры/повара/официанты): видеть только свои заведения
DROP POLICY IF EXISTS customer_order_staff_select ON customer_order;
CREATE POLICY customer_order_staff_select
ON customer_order
FOR SELECT
TO app_managers, app_cooks, app_waiters
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- Менеджеры: менять (INSERT/UPDATE/DELETE) только заказы своих заведений
DROP POLICY IF EXISTS customer_order_manager_write ON customer_order;
CREATE POLICY customer_order_manager_write
ON customer_order
FOR ALL
TO app_managers
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
)
WITH CHECK (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- Официанты: создавать/обновлять только заказы своих заведений
-- (DELETE официантам не выдан GRANT, но политика тоже ограничит)
DROP POLICY IF EXISTS customer_order_waiter_write ON customer_order;
CREATE POLICY customer_order_waiter_write
ON customer_order
FOR INSERT, UPDATE
TO app_waiters
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
)
WITH CHECK (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- =========================================================
-- 4) order_item: политики (через customer_order)
-- =========================================================

-- Администраторы: полный доступ
DROP POLICY IF EXISTS order_item_admin_all ON order_item;
CREATE POLICY order_item_admin_all
ON order_item
FOR ALL
TO app_admins
USING (true)
WITH CHECK (true);

-- Аналитики: чтение всех позиций
DROP POLICY IF EXISTS order_item_analyst_read ON order_item;
CREATE POLICY order_item_analyst_read
ON order_item
FOR SELECT
TO app_analysts
USING (true);

-- Сотрудники: доступ только к позициям заказов своих заведений
DROP POLICY IF EXISTS order_item_staff_access ON order_item;
CREATE POLICY order_item_staff_access
ON order_item
FOR SELECT, INSERT, UPDATE, DELETE
TO app_managers, app_cooks, app_waiters
USING (
  EXISTS (
    SELECT 1
    FROM customer_order co
    WHERE co.order_id = order_item.order_id
      AND co.restaurant_id IN (
        SELECT er.restaurant_id
        FROM employee_restaurant er
        WHERE er.employee_id = get_current_employee_id()
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM customer_order co
    WHERE co.order_id = order_item.order_id
      AND co.restaurant_id IN (
        SELECT er.restaurant_id
        FROM employee_restaurant er
        WHERE er.employee_id = get_current_employee_id()
      )
  )
);

-- =========================================================
-- 5) ingredient_stock: политики
-- =========================================================

-- Администраторы: полный доступ
DROP POLICY IF EXISTS ingredient_stock_admin_all ON ingredient_stock;
CREATE POLICY ingredient_stock_admin_all
ON ingredient_stock
FOR ALL
TO app_admins
USING (true)
WITH CHECK (true);

-- Аналитики: только чтение всего склада
DROP POLICY IF EXISTS ingredient_stock_analyst_read ON ingredient_stock;
CREATE POLICY ingredient_stock_analyst_read
ON ingredient_stock
FOR SELECT
TO app_analysts
USING (true);

-- Менеджеры/повара: видеть склад только своих заведений
DROP POLICY IF EXISTS ingredient_stock_staff_select ON ingredient_stock;
CREATE POLICY ingredient_stock_staff_select
ON ingredient_stock
FOR SELECT
TO app_managers, app_cooks
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- Менеджеры: UPDATE остатков только в своих заведениях
DROP POLICY IF EXISTS ingredient_stock_manager_update ON ingredient_stock;
CREATE POLICY ingredient_stock_manager_update
ON ingredient_stock
FOR UPDATE
TO app_managers
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
)
WITH CHECK (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- =========================================================
-- 6) ingredient_request: политики
-- =========================================================

-- Администраторы: полный доступ
DROP POLICY IF EXISTS ingredient_request_admin_all ON ingredient_request;
CREATE POLICY ingredient_request_admin_all
ON ingredient_request
FOR ALL
TO app_admins
USING (true)
WITH CHECK (true);

-- Аналитики: чтение всех заявок
DROP POLICY IF EXISTS ingredient_request_analyst_read ON ingredient_request;
CREATE POLICY ingredient_request_analyst_read
ON ingredient_request
FOR SELECT
TO app_analysts
USING (true);

-- Менеджеры/повара: видеть заявки только своего заведения
DROP POLICY IF EXISTS ingredient_request_staff_select ON ingredient_request;
CREATE POLICY ingredient_request_staff_select
ON ingredient_request
FOR SELECT
TO app_managers, app_cooks
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- Менеджеры: UPDATE заявок только по своему заведению
DROP POLICY IF EXISTS ingredient_request_manager_update ON ingredient_request;
CREATE POLICY ingredient_request_manager_update
ON ingredient_request
FOR UPDATE
TO app_managers
USING (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
)
WITH CHECK (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

-- Повара: INSERT заявок только для своего заведения
DROP POLICY IF EXISTS ingredient_request_cook_insert ON ingredient_request;
CREATE POLICY ingredient_request_cook_insert
ON ingredient_request
FOR INSERT
TO app_cooks
WITH CHECK (
  restaurant_id IN (
    SELECT er.restaurant_id
    FROM employee_restaurant er
    WHERE er.employee_id = get_current_employee_id()
  )
);

COMMIT;
