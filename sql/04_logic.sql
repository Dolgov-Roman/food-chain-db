-- sql/04_logic.sql
-- Functions, procedures, triggers (automation)

BEGIN;

SET search_path TO food_chain, public;

-- 1) Пересчёт суммы заказа
CREATE OR REPLACE FUNCTION recalc_customer_order_total(p_order_id BIGINT)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_total NUMERIC(12,2);
BEGIN
  SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0)
    INTO v_total
  FROM order_item oi
  WHERE oi.order_id = p_order_id;

  UPDATE customer_order
  SET total_amount = v_total
  WHERE order_id = p_order_id;
END;
$$;

-- Триггерная функция: определить order_id и пересчитать
CREATE OR REPLACE FUNCTION trg_recalc_order_total()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id BIGINT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_order_id := OLD.order_id;
  ELSE
    v_order_id := NEW.order_id;
  END IF;

  PERFORM recalc_customer_order_total(v_order_id);
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_item_recalc_total ON order_item;
CREATE TRIGGER trg_order_item_recalc_total
AFTER INSERT OR UPDATE OR DELETE ON order_item
FOR EACH ROW
EXECUTE FUNCTION trg_recalc_order_total();

-- 2) Автоматическое списание ингредиентов со склада при добавлении позиции заказа
CREATE OR REPLACE FUNCTION trg_deduct_ingredient_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_restaurant_id BIGINT;
  rec RECORD;
  v_stock_id BIGINT;
BEGIN
  -- Определяем заведение, где оформлен заказ
  SELECT co.restaurant_id
    INTO v_restaurant_id
  FROM customer_order co
  WHERE co.order_id = NEW.order_id;

  IF v_restaurant_id IS NULL THEN
    RAISE EXCEPTION 'Order % not found or has no restaurant_id', NEW.order_id;
  END IF;

  -- Для каждого ингредиента блюда: списываем quantity * порции
  FOR rec IN
    SELECT di.ingredient_id,
           di.quantity AS qty_per_portion
    FROM dish_ingredient di
    WHERE di.dish_id = NEW.dish_id
  LOOP
    -- Берём одну подходящую строку склада (самую раннюю по сроку годности/поставке)
    SELECT s.stock_id
      INTO v_stock_id
    FROM ingredient_stock s
    WHERE s.restaurant_id = v_restaurant_id
      AND s.ingredient_id = rec.ingredient_id
      AND s.quantity >= (rec.qty_per_portion * NEW.quantity)
    ORDER BY
      COALESCE(s.expiry_date, DATE '9999-12-31') ASC,
      COALESCE(s.received_date, DATE '9999-12-31') ASC,
      s.stock_id ASC
    LIMIT 1;

    IF v_stock_id IS NULL THEN
      RAISE EXCEPTION
        'Not enough stock for ingredient_id=% in restaurant_id=% (dish_id=%, order_id=%)',
        rec.ingredient_id, v_restaurant_id, NEW.dish_id, NEW.order_id;
    END IF;

    UPDATE ingredient_stock
    SET quantity = quantity - (rec.qty_per_portion * NEW.quantity)
    WHERE stock_id = v_stock_id;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_item_deduct_stock ON order_item;
CREATE TRIGGER trg_order_item_deduct_stock
AFTER INSERT ON order_item
FOR EACH ROW
EXECUTE FUNCTION trg_deduct_ingredient_stock();

-- 3) Процедура закрытия заказа с записью отзыва
CREATE OR REPLACE PROCEDURE close_order_with_feedback(
  p_order_id BIGINT,
  p_rating INTEGER,
  p_comment TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Переводим заказ в статус PAID
  UPDATE customer_order
  SET status_code = 'PAID'
  WHERE order_id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order % not found', p_order_id;
  END IF;

  -- Если оценка не передана, отзыв не пишем
  IF p_rating IS NULL THEN
    RETURN;
  END IF;

  -- Upsert отзыва по order_id (у нас order_feedback.order_id UNIQUE)
  INSERT INTO order_feedback (order_id, rating, comment, created_at, would_recommend)
  VALUES (
    p_order_id,
    p_rating,
    p_comment,
    now(),
    CASE WHEN p_rating >= 4 THEN TRUE ELSE FALSE END
  )
  ON CONFLICT (order_id) DO UPDATE
  SET rating = EXCLUDED.rating,
      comment = EXCLUDED.comment,
      created_at = EXCLUDED.created_at,
      would_recommend = EXCLUDED.would_recommend;
END;
$$;

COMMIT;
