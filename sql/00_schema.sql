-- sql/00_schema.sql
-- Schema: food_chain
-- Reconstructed from report description

BEGIN;

-- (опционально) отдельная схема
CREATE SCHEMA IF NOT EXISTS food_chain;
SET search_path TO food_chain, public;

-- 1) city
CREATE TABLE IF NOT EXISTS city (
  city_id      BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  region       TEXT
);

-- 2) position
CREATE TABLE IF NOT EXISTS position (
  position_id  BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  description  TEXT
);

-- 3) dish_category
CREATE TABLE IF NOT EXISTS dish_category (
  category_id  BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  description  TEXT
);

-- 4) order_status
CREATE TABLE IF NOT EXISTS order_status (
  status_code  TEXT PRIMARY KEY,   -- NEW, IN_PROGRESS, READY, PAID, CANCELLED
  name         TEXT NOT NULL,
  description  TEXT
);

-- 5) role
CREATE TABLE IF NOT EXISTS role (
  role_id      BIGSERIAL PRIMARY KEY,
  code         TEXT NOT NULL UNIQUE,  -- admin, analyst, manager, cook, waiter
  name         TEXT NOT NULL,
  description  TEXT
);

-- 6) restaurant
CREATE TABLE IF NOT EXISTS restaurant (
  restaurant_id     BIGSERIAL PRIMARY KEY,
  city_id           BIGINT NOT NULL REFERENCES city(city_id),
  name              TEXT NOT NULL,
  type              TEXT NOT NULL, -- ресторан, суши-бар...
  address           TEXT NOT NULL,
  postal_code       TEXT,
  phone             TEXT,
  employees_count   INTEGER,
  seats_count       INTEGER NOT NULL CHECK (seats_count >= 0),
  opening_time      TIME NOT NULL,
  closing_time      TIME NOT NULL,
  CONSTRAINT uq_restaurant_city_name UNIQUE (city_id, name)
);

-- 7) employee
CREATE TABLE IF NOT EXISTS employee (
  employee_id        BIGSERIAL PRIMARY KEY,
  city_id            BIGINT NOT NULL REFERENCES city(city_id),
  position_id        BIGINT NOT NULL REFERENCES position(position_id),
  last_name          TEXT NOT NULL,
  first_name         TEXT NOT NULL,
  middle_name        TEXT,
  phone              TEXT,
  email              TEXT,
  hire_date          DATE NOT NULL,
  experience_years   INTEGER CHECK (experience_years IS NULL OR experience_years >= 0),
  salary             NUMERIC(12,2) CHECK (salary IS NULL OR salary >= 0),
  birth_date         DATE,
  short_info         TEXT,
  is_active          BOOLEAN NOT NULL DEFAULT TRUE
);

-- 8) employee_restaurant (M:N)
CREATE TABLE IF NOT EXISTS employee_restaurant (
  employee_id   BIGINT NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
  restaurant_id BIGINT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (employee_id, restaurant_id)
);

-- 9) app_user (1:1 с employee)
CREATE TABLE IF NOT EXISTS app_user (
  user_id        BIGSERIAL PRIMARY KEY,
  employee_id    BIGINT UNIQUE REFERENCES employee(employee_id) ON DELETE SET NULL,
  login          TEXT NOT NULL UNIQUE,
  password_hash  TEXT NOT NULL,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10) user_role (M:N)
CREATE TABLE IF NOT EXISTS user_role (
  user_id  BIGINT NOT NULL REFERENCES app_user(user_id) ON DELETE CASCADE,
  role_id  BIGINT NOT NULL REFERENCES role(role_id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

-- 11) ingredient
CREATE TABLE IF NOT EXISTS ingredient (
  ingredient_id  BIGSERIAL PRIMARY KEY,
  name           TEXT NOT NULL UNIQUE,
  unit           TEXT NOT NULL, -- кг, г, л, мл, шт...
  description    TEXT
);

-- 12) supplier
CREATE TABLE IF NOT EXISTS supplier (
  supplier_id  BIGSERIAL PRIMARY KEY,
  name         TEXT NOT NULL UNIQUE,
  phone        TEXT,
  email        TEXT,
  address      TEXT
);

-- 13) ingredient_stock
CREATE TABLE IF NOT EXISTS ingredient_stock (
  stock_id       BIGSERIAL PRIMARY KEY,
  restaurant_id  BIGINT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  ingredient_id  BIGINT NOT NULL REFERENCES ingredient(ingredient_id),
  supplier_id    BIGINT REFERENCES supplier(supplier_id),
  quantity       NUMERIC(14,3) NOT NULL CHECK (quantity >= 0),
  unit_price     NUMERIC(12,2) CHECK (unit_price IS NULL OR unit_price >= 0),
  received_date  DATE,
  expiry_date    DATE,
  CONSTRAINT ck_stock_dates CHECK (expiry_date IS NULL OR received_date IS NULL OR expiry_date >= received_date)
);

-- 14) dish
CREATE TABLE IF NOT EXISTS dish (
  dish_id        BIGSERIAL PRIMARY KEY,
  restaurant_id  BIGINT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  category_id    BIGINT NOT NULL REFERENCES dish_category(category_id),
  name           TEXT NOT NULL,
  price          NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  cook_time_min  INTEGER CHECK (cook_time_min IS NULL OR cook_time_min >= 0),
  is_available   BOOLEAN NOT NULL DEFAULT TRUE,
  is_deleted     BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT uq_dish_restaurant_name UNIQUE (restaurant_id, name)
);

-- 15) dish_ingredient (M:N)
CREATE TABLE IF NOT EXISTS dish_ingredient (
  dish_id        BIGINT NOT NULL REFERENCES dish(dish_id) ON DELETE CASCADE,
  ingredient_id  BIGINT NOT NULL REFERENCES ingredient(ingredient_id),
  quantity       NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (dish_id, ingredient_id)
);

-- 16) restaurant_table
CREATE TABLE IF NOT EXISTS restaurant_table (
  table_id       BIGSERIAL PRIMARY KEY,
  restaurant_id  BIGINT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  table_number   TEXT NOT NULL,
  seats          INTEGER NOT NULL CHECK (seats >= 0),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_table_restaurant_number UNIQUE (restaurant_id, table_number)
);

-- 17) customer_order
CREATE TABLE IF NOT EXISTS customer_order (
  order_id          BIGSERIAL PRIMARY KEY,
  restaurant_id     BIGINT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  table_id          BIGINT REFERENCES restaurant_table(table_id),
  waiter_id         BIGINT REFERENCES employee(employee_id),
  order_datetime    TIMESTAMPTZ NOT NULL DEFAULT now(),
  status_code       TEXT NOT NULL REFERENCES order_status(status_code),
  guests_count      INTEGER CHECK (guests_count IS NULL OR guests_count >= 0),
  special_requests  TEXT,
  total_amount      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

-- 18) order_item
CREATE TABLE IF NOT EXISTS order_item (
  order_item_id  BIGSERIAL PRIMARY KEY,
  order_id       BIGINT NOT NULL REFERENCES customer_order(order_id) ON DELETE CASCADE,
  dish_id        BIGINT NOT NULL REFERENCES dish(dish_id),
  quantity       INTEGER NOT NULL CHECK (quantity > 0),
  unit_price     NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  comment        TEXT
);

-- 19) ingredient_request
CREATE TABLE IF NOT EXISTS ingredient_request (
  request_id       BIGSERIAL PRIMARY KEY,
  restaurant_id    BIGINT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  employee_id      BIGINT NOT NULL REFERENCES employee(employee_id),
  ingredient_id    BIGINT NOT NULL REFERENCES ingredient(ingredient_id),
  quantity         NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
  status           TEXT NOT NULL, -- NEW, APPROVED, REJECTED, ORDERED, DONE
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at     TIMESTAMPTZ,
  manager_comment  TEXT,
  CONSTRAINT ck_req_processed CHECK (processed_at IS NULL OR processed_at >= created_at)
);

-- 20) order_feedback
CREATE TABLE IF NOT EXISTS order_feedback (
  feedback_id       BIGSERIAL PRIMARY KEY,
  order_id          BIGINT NOT NULL UNIQUE REFERENCES customer_order(order_id) ON DELETE CASCADE,
  rating            INTEGER CHECK (rating IS NULL OR (rating BETWEEN 1 AND 5)),
  comment           TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  would_recommend   BOOLEAN
);

COMMIT;
