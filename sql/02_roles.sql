-- sql/02_roles.sql
-- Roles, group roles, privileges

BEGIN;

SET search_path TO food_chain, public;

-- 1) REVOKE прав у PUBLIC
REVOKE ALL ON DATABASE food_chain FROM PUBLIC;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA food_chain FROM PUBLIC;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA food_chain FROM PUBLIC;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA food_chain FROM PUBLIC;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA food_chain FROM PUBLIC;

-- 2) Групповые роли (NOLOGIN)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_admins') THEN
    CREATE ROLE app_admins NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_analysts') THEN
    CREATE ROLE app_analysts NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_managers') THEN
    CREATE ROLE app_managers NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_cooks') THEN
    CREATE ROLE app_cooks NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_waiters') THEN
    CREATE ROLE app_waiters NOLOGIN;
  END IF;
END $$;

-- 3) Пользователи (LOGIN)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='admin_user') THEN
    CREATE ROLE admin_user LOGIN PASSWORD 'changeme_admin';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='analyst_user') THEN
    CREATE ROLE analyst_user LOGIN PASSWORD 'changeme_analyst';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='manager_user') THEN
    CREATE ROLE manager_user LOGIN PASSWORD 'changeme_manager';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='cook_user') THEN
    CREATE ROLE cook_user LOGIN PASSWORD 'changeme_cook';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='waiter_user') THEN
    CREATE ROLE waiter_user LOGIN PASSWORD 'changeme_waiter';
  END IF;
END $$;

-- 4) Назначение пользователей в групповые роли
GRANT app_admins   TO admin_user;
GRANT app_analysts TO analyst_user;
GRANT app_managers TO manager_user;
GRANT app_cooks    TO cook_user;
GRANT app_waiters  TO waiter_user;

-- 5) Права app_admins (полный доступ)
GRANT CONNECT, TEMPORARY ON DATABASE food_chain TO app_admins;

GRANT USAGE, CREATE ON SCHEMA public TO app_admins;
GRANT USAGE, CREATE ON SCHEMA food_chain TO app_admins;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admins;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA food_chain TO app_admins;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_admins;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA food_chain TO app_admins;

GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO app_admins;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA food_chain TO app_admins;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO app_admins;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO app_admins;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO app_admins;

ALTER DEFAULT PRIVILEGES IN SCHEMA food_chain
  GRANT ALL ON TABLES TO app_admins;
ALTER DEFAULT PRIVILEGES IN SCHEMA food_chain
  GRANT ALL ON SEQUENCES TO app_admins;
ALTER DEFAULT PRIVILEGES IN SCHEMA food_chain
  GRANT ALL ON FUNCTIONS TO app_admins;

-- 6) Права app_analysts (только чтение)
GRANT CONNECT ON DATABASE food_chain TO app_analysts;

GRANT USAGE ON SCHEMA public TO app_analysts;
GRANT USAGE ON SCHEMA food_chain TO app_analysts;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_analysts;
GRANT SELECT ON ALL TABLES IN SCHEMA food_chain TO app_analysts;

GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO app_analysts;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA food_chain TO app_analysts;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO app_analysts;
ALTER DEFAULT PRIVILEGES IN SCHEMA food_chain
  GRANT SELECT ON TABLES TO app_analysts;

-- 7) Права app_managers (чтение справочников + управление заказами + склад)
GRANT CONNECT ON DATABASE food_chain TO app_managers;

GRANT USAGE ON SCHEMA public TO app_managers;
GRANT USAGE ON SCHEMA food_chain TO app_managers;

-- справочники/служебные: только чтение
GRANT SELECT ON TABLE
  city, position, restaurant, employee, employee_restaurant,
  dish_category, dish, dish_ingredient,
  order_status,
  restaurant_table,
  role, app_user, user_role,
  supplier, ingredient,
  order_feedback
TO app_managers;

-- заказы: полные права
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  customer_order, order_item
TO app_managers;

-- склад: просмотр и обновление остатков
GRANT SELECT, UPDATE ON TABLE ingredient_stock TO app_managers;

-- заявки: просмотр/создание/изменение
GRANT SELECT, INSERT, UPDATE ON TABLE ingredient_request TO app_managers;

-- 8) Права app_cooks (чтение + создание заявок)
GRANT CONNECT ON DATABASE food_chain TO app_cooks;

GRANT USAGE ON SCHEMA public TO app_cooks;
GRANT USAGE ON SCHEMA food_chain TO app_cooks;

-- чтение заведений/столиков/меню/составов/заказов/статусов/склада
GRANT SELECT ON TABLE
  restaurant, restaurant_table,
  dish_category, dish, dish_ingredient,
  customer_order, order_item,
  order_status,
  ingredient_stock,
  ingredient
TO app_cooks;

-- заявки: смотреть + создавать
GRANT SELECT, INSERT ON TABLE ingredient_request TO app_cooks;

-- 9) Права app_waiters (чтение справочников + работа с заказами без удаления)
GRANT CONNECT ON DATABASE food_chain TO app_waiters;

GRANT USAGE ON SCHEMA public TO app_waiters;
GRANT USAGE ON SCHEMA food_chain TO app_waiters;

GRANT SELECT ON TABLE
  restaurant, restaurant_table,
  dish_category, dish,
  order_status
TO app_waiters;

GRANT SELECT, INSERT, UPDATE ON TABLE
  customer_order, order_item
TO app_waiters;

COMMIT;
