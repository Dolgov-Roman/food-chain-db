-- sql/06_extra.sql
-- Extra tasks: booking alternatives + employee performance reporting

BEGIN;

SET search_path TO food_chain, public;

-- =========================================================
-- 1) suggest_booking_alternatives
-- =========================================================
-- Возвращает варианты:
--  - type='time' -> альтернативное время в том же ресторане
--  - type='restaurant' -> другой ресторан в том же городе

CREATE OR REPLACE FUNCTION suggest_booking_alternatives(
  p_restaurant_id BIGINT,
  p_desired_time  TIMESTAMPTZ,
  p_guests        INTEGER,
  p_max_orders    INTEGER DEFAULT 20
)
RETURNS TABLE (
  suggestion_type TEXT,
  suggested_time  TIMESTAMPTZ,
  suggested_restaurant_id BIGINT,
  message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_orders_cnt INTEGER;
  v_has_free_table BOOLEAN;
  v_slot TIMESTAMPTZ;
  v_city_id BIGINT;
BEGIN
  IF p_guests IS NULL OR p_guests <= 0 THEN
    RAISE EXCEPTION 'p_guests must be positive';
  END IF;

  -- Заказы в окне +-1 час
  SELECT COUNT(*)
  INTO v_orders_cnt
  FROM customer_order co
  WHERE co.restaurant_id = p_restaurant_id
    AND co.order_datetime BETWEEN (p_desired_time - interval '1 hour')
                             AND (p_desired_time + interval '1 hour')
    AND co.status_code <> 'CANCELLED';

  -- Есть ли свободный столик нужной вместимости:
  -- "свободный" = активный столик, на который нет заказа в том же окне +-1 час
  SELECT EXISTS (
    SELECT 1
    FROM restaurant_table rt
    WHERE rt.restaurant_id = p_restaurant_id
      AND rt.is_active = TRUE
      AND rt.seats >= p_guests
      AND NOT EXISTS (
        SELECT 1
        FROM customer_order co
        WHERE co.restaurant_id = p_restaurant_id
          AND co.table_id = rt.table_id
          AND co.order_datetime BETWEEN (p_desired_time - interval '1 hour')
                                   AND (p_desired_time + interval '1 hour')
          AND co.status_code <> 'CANCELLED'
      )
  ) INTO v_has_free_table;

  -- Если всё ок — альтернативы не нужны, ничего не возвращаем
  IF v_has_free_table AND v_orders_cnt <= p_max_orders THEN
    RETURN;
  END IF;

  -- 1) Ищем другое время в том же ресторане: шаг 30 минут до +3 часов
  v_slot := p_desired_time + interval '30 minutes';
  WHILE v_slot <= p_desired_time + interval '3 hours' LOOP
    SELECT EXISTS (
      SELECT 1
      FROM restaurant_table rt
      WHERE rt.restaurant_id = p_restaurant_id
        AND rt.is_active = TRUE
        AND rt.seats >= p_guests
        AND NOT EXISTS (
          SELECT 1
          FROM customer_order co
          WHERE co.restaurant_id = p_restaurant_id
            AND co.table_id = rt.table_id
            AND co.order_datetime BETWEEN (v_slot - interval '1 hour')
                                     AND (v_slot + interval '1 hour')
            AND co.status_code <> 'CANCELLED'
        )
    ) INTO v_has_free_table;

    SELECT COUNT(*)
    INTO v_orders_cnt
    FROM customer_order co
    WHERE co.restaurant_id = p_restaurant_id
      AND co.order_datetime BETWEEN (v_slot - interval '1 hour')
                               AND (v_slot + interval '1 hour')
      AND co.status_code <> 'CANCELLED';

    IF v_has_free_table AND v_orders_cnt <= p_max_orders THEN
      suggestion_type := 'time';
      suggested_time := v_slot;
      suggested_restaurant_id := p_restaurant_id;
      message := 'Предложить другое время в том же заведении';
      RETURN NEXT;
      -- можно вернуть несколько вариантов времени, поэтому не выходим
    END IF;

    v_slot := v_slot + interval '30 minutes';
  END LOOP;

  -- 2) Если времени не нашли — предлагаем другие рестораны в том же городе
  SELECT r.city_id INTO v_city_id
  FROM restaurant r
  WHERE r.restaurant_id = p_restaurant_id;

  FOR suggested_restaurant_id IN
    SELECT r2.restaurant_id
    FROM restaurant r2
    WHERE r2.city_id = v_city_id
      AND r2.restaurant_id <> p_restaurant_id
    ORDER BY r2.restaurant_id
  LOOP
    SELECT EXISTS (
      SELECT 1
      FROM restaurant_table rt
      WHERE rt.restaurant_id = suggested_restaurant_id
        AND rt.is_active = TRUE
        AND rt.seats >= p_guests
        AND NOT EXISTS (
          SELECT 1
          FROM customer_order co
          WHERE co.restaurant_id = suggested_restaurant_id
            AND co.table_id = rt.table_id
            AND co.order_datetime BETWEEN (p_desired_time - interval '1 hour')
                                     AND (p_desired_time + interval '1 hour')
            AND co.status_code <> 'CANCELLED'
        )
    ) INTO v_has_free_table;

    IF v_has_free_table THEN
      suggestion_type := 'restaurant';
      suggested_time := p_desired_time;
      message := 'Предложить бронирование в другом заведении поблизости (в том же городе)';
      RETURN NEXT;
    END IF;
  END LOOP;

  RETURN;
END;
$$;

-- =========================================================
-- 2) Представление order_performance
-- =========================================================
DROP VIEW IF EXISTS order_performance;
CREATE VIEW order_performance AS
SELECT
  co.order_id,
  co.restaurant_id,
  co.waiter_id,
  co.order_datetime,
  co.status_code,
  co.total_amount,
  ofb.rating,
  ofb.comment AS feedback_comment,
  ofb.created_at AS feedback_datetime,
  CASE
    WHEN ofb.created_at IS NULL THEN NULL
    ELSE ROUND(EXTRACT(EPOCH FROM (ofb.created_at - co.order_datetime)) / 60.0, 2)
  END AS duration_min
FROM customer_order co
LEFT JOIN order_feedback ofb
  ON ofb.order_id = co.order_id;

-- =========================================================
-- 3) employee_performance_report(p_from, p_to)
-- =========================================================
CREATE OR REPLACE FUNCTION employee_performance_report(
  p_from TIMESTAMPTZ,
  p_to   TIMESTAMPTZ
)
RETURNS TABLE (
  employee_id BIGINT,
  employee_fio TEXT,
  position_name TEXT,
  restaurant_id BIGINT,
  restaurant_name TEXT,
  orders_total BIGINT,
  orders_completed BIGINT,
  avg_order_value NUMERIC(12,2),
  avg_completion_min NUMERIC(12,2),
  avg_rating NUMERIC(5,2),
  rating_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.employee_id,
    (e.last_name || ' ' || e.first_name || COALESCE(' ' || e.middle_name, '')) AS employee_fio,
    p.name AS position_name,
    r.restaurant_id,
    r.name AS restaurant_name,

    COUNT(co.order_id) FILTER (
      WHERE co.order_datetime >= p_from AND co.order_datetime < p_to
        AND co.waiter_id = e.employee_id
    ) AS orders_total,

    COUNT(co.order_id) FILTER (
      WHERE co.order_datetime >= p_from AND co.order_datetime < p_to
        AND co.waiter_id = e.employee_id
        AND co.status_code = 'PAID'
    ) AS orders_completed,

    ROUND(AVG(co.total_amount) FILTER (
      WHERE co.order_datetime >= p_from AND co.order_datetime < p_to
        AND co.waiter_id = e.employee_id
        AND co.status_code = 'PAID'
    )::numeric, 2) AS avg_order_value,

    ROUND(AVG(op.duration_min) FILTER (
      WHERE op.order_datetime >= p_from AND op.order_datetime < p_to
        AND op.waiter_id = e.employee_id
        AND op.status_code = 'PAID'
        AND op.duration_min IS NOT NULL
    )::numeric, 2) AS avg_completion_min,

    ROUND(AVG(op.rating) FILTER (
      WHERE op.order_datetime >= p_from AND op.order_datetime < p_to
        AND op.waiter_id = e.employee_id
        AND op.rating IS NOT NULL
    )::numeric, 2) AS avg_rating,

    COUNT(op.rating) FILTER (
      WHERE op.order_datetime >= p_from AND op.order_datetime < p_to
        AND op.waiter_id = e.employee_id
        AND op.rating IS NOT NULL
    ) AS rating_count

  FROM employee e
  JOIN position p ON p.position_id = e.position_id
  -- связываем сотрудника с заведением(ями) через employee_restaurant
  JOIN employee_restaurant er ON er.employee_id = e.employee_id
  JOIN restaurant r ON r.restaurant_id = er.restaurant_id
  LEFT JOIN customer_order co
    ON co.waiter_id = e.employee_id
   AND co.restaurant_id = r.restaurant_id
  LEFT JOIN order_performance op
    ON op.order_id = co.order_id

  GROUP BY e.employee_id, employee_fio, p.name, r.restaurant_id, r.name
  ORDER BY orders_completed DESC, avg_rating DESC NULLS LAST;
END;
$$;

COMMIT;
