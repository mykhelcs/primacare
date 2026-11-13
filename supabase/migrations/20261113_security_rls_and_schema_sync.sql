-- ============================================================================
-- PrimaCare Smart Clinic — Security Hardening, RLS Cleanup & Schema Sync
-- Migration: 20261113_security_rls_and_schema_sync.sql
-- ============================================================================

BEGIN;

-- 1. Schema Sync: Settlement Audit Columns & Statutory Discount Columns on Invoices
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS discount_type text DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS discount_percentage numeric(5,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS discount_id_number text,
  ADD COLUMN IF NOT EXISTS payment_method text,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

-- 2. Schema Sync: Allow 'expiry_alert' notifications in notifications_queue
ALTER TABLE public.notifications_queue
  DROP CONSTRAINT IF EXISTS notifications_queue_type_check;
ALTER TABLE public.notifications_queue
  ADD CONSTRAINT notifications_queue_type_check
  CHECK (type IN ('vaccine_reminder', 'follow_up', 'bill_reminder', 'expiry_alert'));

-- 3. Admin-Restricted Reporting Views (Security Invoker enforces caller RLS)
CREATE OR REPLACE VIEW public.view_monthly_billing_summary
WITH (security_invoker = true) AS
SELECT
  to_char(inv.created_at AT TIME ZONE 'Asia/Manila', 'YYYY-MM') AS month_key,
  COUNT(inv.id) AS total_invoices,
  COUNT(CASE WHEN inv.status = 'paid' THEN 1 END) AS paid_invoices,
  COUNT(CASE WHEN inv.status = 'open' THEN 1 END) AS open_invoices,
  COALESCE(SUM(inv.total_amount), 0) AS total_billed_amount,
  COALESCE(SUM(CASE WHEN inv.status = 'paid' THEN inv.total_amount ELSE 0 END), 0) AS total_collected_amount
FROM public.invoices inv
WHERE EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid()
    AND u.role = 'admin'
    AND (inv.clinic_id IS NULL OR inv.clinic_id = u.clinic_id)
)
GROUP BY to_char(inv.created_at AT TIME ZONE 'Asia/Manila', 'YYYY-MM')
ORDER BY month_key DESC;

CREATE OR REPLACE VIEW public.view_revenue_leakage_prevented
WITH (security_invoker = true) AS
SELECT
  ili.item_name,
  COUNT(ili.id) AS dispensation_count,
  SUM(ili.quantity) AS total_units_dispensed,
  SUM(ili.line_total) AS total_revenue_captured
FROM public.invoice_line_items ili
JOIN public.invoices inv ON ili.invoice_id = inv.id
WHERE EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid()
    AND u.role = 'admin'
    AND (inv.clinic_id IS NULL OR inv.clinic_id = u.clinic_id)
)
GROUP BY ili.item_name
ORDER BY total_revenue_captured DESC;

REVOKE ALL ON public.view_monthly_billing_summary FROM PUBLIC, anon;
REVOKE ALL ON public.view_revenue_leakage_prevented FROM PUBLIC, anon;
GRANT SELECT ON public.view_monthly_billing_summary TO authenticated;
GRANT SELECT ON public.view_revenue_leakage_prevented TO authenticated;

-- 4. Lock Down RLS Policies (Authenticated Clinical Staff Only — Never Anon)
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- Remove any permissive/anon policies from earlier migrations
  DROP POLICY IF EXISTS "Allow all access to inventory items" ON public.inventory_items;
  DROP POLICY IF EXISTS "Allow all access to inventory batches" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Allow all access to patients" ON public.patients;
  DROP POLICY IF EXISTS "Allow all access to invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Allow all access to invoice line items" ON public.invoice_line_items;

  DROP POLICY IF EXISTS "Allow authenticated staff to read clinics" ON public.clinics;
  CREATE POLICY "Allow authenticated staff to read clinics"
    ON public.clinics FOR SELECT
    TO authenticated
    USING (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Users read own profile" ON public.users;
  CREATE POLICY "Users read own profile"
    ON public.users FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

  DROP POLICY IF EXISTS "Staff can view patients" ON public.patients;
  DROP POLICY IF EXISTS "Staff can register patients" ON public.patients;
  DROP POLICY IF EXISTS "Staff can update patients" ON public.patients;
  DROP POLICY IF EXISTS "Staff authenticated read patients" ON public.patients;
  DROP POLICY IF EXISTS "Staff authenticated insert patients" ON public.patients;
  DROP POLICY IF EXISTS "Staff authenticated update patients" ON public.patients;

  CREATE POLICY "Staff authenticated read patients" ON public.patients
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated insert patients" ON public.patients
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated update patients" ON public.patients
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff can view inventory" ON public.inventory_items;
  DROP POLICY IF EXISTS "Staff authenticated read inventory" ON public.inventory_items;
  DROP POLICY IF EXISTS "Staff authenticated manage inventory" ON public.inventory_items;

  CREATE POLICY "Staff authenticated read inventory" ON public.inventory_items
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated manage inventory" ON public.inventory_items
    FOR ALL TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff can view batches" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Staff can insert batches" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Staff can update batch quantities" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Staff authenticated read batches" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Staff authenticated manage batches" ON public.inventory_batches;

  CREATE POLICY "Staff authenticated read batches" ON public.inventory_batches
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated manage batches" ON public.inventory_batches
    FOR ALL TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff can view invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Staff can insert invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Staff can update invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Staff authenticated read invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Staff authenticated insert invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Staff authenticated update invoices" ON public.invoices;

  CREATE POLICY "Staff authenticated read invoices" ON public.invoices
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated insert invoices" ON public.invoices
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated update invoices" ON public.invoices
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff can view invoice lines" ON public.invoice_line_items;
  DROP POLICY IF EXISTS "Staff can insert invoice lines" ON public.invoice_line_items;
  DROP POLICY IF EXISTS "Staff authenticated read invoice lines" ON public.invoice_line_items;
  DROP POLICY IF EXISTS "Staff authenticated insert invoice lines" ON public.invoice_line_items;

  CREATE POLICY "Staff authenticated read invoice lines" ON public.invoice_line_items
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff authenticated insert invoice lines" ON public.invoice_line_items
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff can view notifications" ON public.notifications_queue;
  DROP POLICY IF EXISTS "Staff can queue notifications" ON public.notifications_queue;
  DROP POLICY IF EXISTS "Staff can update notifications" ON public.notifications_queue;

  CREATE POLICY "Staff can view notifications" ON public.notifications_queue
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff can queue notifications" ON public.notifications_queue
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  CREATE POLICY "Staff can update notifications" ON public.notifications_queue
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);
END
$$;

-- 5. Auth User Profile Sync Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, full_name, role, clinic_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(
      CASE
        WHEN NEW.raw_user_meta_data ->> 'role' IN ('admin', 'doctor', 'nurse')
        THEN NEW.raw_user_meta_data ->> 'role'
      END,
      'nurse'
    ),
    '00000000-0000-0000-0000-000000000001'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. Hardened RPCs: Authenticated Guard, Paid-Invoice Guard, Service Item Support, Batch Validation
CREATE OR REPLACE FUNCTION public.dispense_item(
  p_barcode text,
  p_invoice_id uuid,
  p_quantity int DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item public.inventory_items%ROWTYPE;
  v_batch public.inventory_batches%ROWTYPE;
  v_invoice_status text;
  v_needed int := p_quantity;
  v_deduct int;
  v_total_added numeric(10,2) := 0;
  v_batches_dispensed text[] := ARRAY[]::text[];
  v_manila_today date := (now() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
  IF auth.uid() IS NULL AND current_setting('role', true) NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Authentication required.');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Dispensation quantity must be greater than zero.');
  END IF;

  IF p_barcode IS NULL OR btrim(p_barcode) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode cannot be empty.');
  END IF;

  SELECT * INTO v_item FROM public.inventory_items WHERE barcode = btrim(p_barcode);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode not found in clinic formulary.');
  END IF;

  SELECT status INTO v_invoice_status
  FROM public.invoices
  WHERE id = p_invoice_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Target invoice not found.');
  END IF;

  IF v_invoice_status = 'paid' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cannot modify a settled invoice.');
  END IF;

  IF lower(COALESCE(v_item.category, '')) = 'services' THEN
    INSERT INTO public.invoice_line_items (
      invoice_id, inventory_batch_id, item_name, quantity, unit_cost
    ) VALUES (
      p_invoice_id, NULL, v_item.name, p_quantity, v_item.unit_cost
    );

    v_total_added := p_quantity * v_item.unit_cost;

    UPDATE public.invoices
    SET total_amount = total_amount + v_total_added
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
      'success', true,
      'item_name', v_item.name,
      'quantity_dispensed', p_quantity,
      'amount_added', v_total_added,
      'batches_used', ARRAY['Clinical Service'],
      'fefo_enforced', false
    );
  END IF;

  IF (SELECT COALESCE(SUM(quantity_remaining), 0)
      FROM public.inventory_batches
      WHERE item_id = v_item.id AND expiry_date >= v_manila_today) < p_quantity THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient unexpired stock available for ' || v_item.name || '.');
  END IF;

  FOR v_batch IN
    SELECT * FROM public.inventory_batches
    WHERE item_id = v_item.id
      AND quantity_remaining > 0
      AND expiry_date >= v_manila_today
    ORDER BY expiry_date ASC, received_date ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_needed <= 0;

    v_deduct := LEAST(v_batch.quantity_remaining, v_needed);

    UPDATE public.inventory_batches
    SET quantity_remaining = quantity_remaining - v_deduct
    WHERE id = v_batch.id;

    INSERT INTO public.invoice_line_items (
      invoice_id, inventory_batch_id, item_name, quantity, unit_cost
    ) VALUES (
      p_invoice_id, v_batch.id, v_item.name, v_deduct, v_item.unit_cost
    );

    v_total_added := v_total_added + (v_deduct * v_item.unit_cost);
    v_batches_dispensed := array_append(v_batches_dispensed, v_batch.batch_number || ' (qty: ' || v_deduct || ')');
    v_needed := v_needed - v_deduct;
  END LOOP;

  IF v_needed > 0 THEN
    RAISE EXCEPTION 'Concurrent stock depletion detected for %', v_item.name;
  END IF;

  UPDATE public.invoices
  SET total_amount = total_amount + v_total_added
  WHERE id = p_invoice_id;

  RETURN jsonb_build_object(
    'success', true,
    'item_name', v_item.name,
    'quantity_dispensed', p_quantity,
    'amount_added', v_total_added,
    'batches_used', v_batches_dispensed,
    'fefo_enforced', true
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Dispensation failed: ' || SQLERRM
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.dispense_item_tenant(
  p_clinic_id uuid,
  p_invoice_id uuid,
  p_item_id uuid,
  p_quantity int
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch_id uuid;
  v_batch_num text;
  v_unit_cost numeric(10,2);
  v_item_name text;
  v_category text;
  v_invoice_status text;
  v_new_total numeric(10,2);
  v_manila_today date := (now() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
  IF auth.uid() IS NULL AND current_setting('role', true) NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required.');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be greater than zero.');
  END IF;

  SELECT status INTO v_invoice_status
  FROM public.invoices
  WHERE id = p_invoice_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target invoice not found.');
  END IF;

  IF v_invoice_status = 'paid' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot modify a settled invoice.');
  END IF;

  SELECT name, unit_cost, category INTO v_item_name, v_unit_cost, v_category
  FROM public.inventory_items
  WHERE id = p_item_id AND (clinic_id = p_clinic_id OR clinic_id IS NULL);

  IF v_item_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found in current clinic.');
  END IF;

  IF lower(COALESCE(v_category, '')) = 'services' THEN
    INSERT INTO public.invoice_line_items (
      invoice_id, inventory_batch_id, item_name, quantity, unit_cost
    ) VALUES (
      p_invoice_id, NULL, v_item_name, p_quantity, v_unit_cost
    );

    SELECT COALESCE(SUM(quantity * unit_cost), 0)
    INTO v_new_total
    FROM public.invoice_line_items
    WHERE invoice_id = p_invoice_id;

    UPDATE public.invoices
    SET total_amount = v_new_total
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
      'success', true,
      'batch_number', 'Clinical Service',
      'unit_cost', v_unit_cost,
      'total_amount', v_new_total,
      'fefo_enforced', false
    );
  END IF;

  SELECT id, batch_number
  INTO v_batch_id, v_batch_num
  FROM public.inventory_batches
  WHERE item_id = p_item_id
    AND (clinic_id = p_clinic_id OR clinic_id IS NULL)
    AND quantity_remaining >= p_quantity
    AND expiry_date >= v_manila_today
  ORDER BY expiry_date ASC, received_date ASC
  LIMIT 1
  FOR UPDATE;

  IF v_batch_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient unexpired stock in clinic for FEFO dispensation.');
  END IF;

  UPDATE public.inventory_batches
  SET quantity_remaining = quantity_remaining - p_quantity
  WHERE id = v_batch_id;

  INSERT INTO public.invoice_line_items (
    invoice_id, inventory_batch_id, item_name, quantity, unit_cost
  ) VALUES (
    p_invoice_id, v_batch_id, v_item_name, p_quantity, v_unit_cost
  );

  SELECT COALESCE(SUM(quantity * unit_cost), 0)
  INTO v_new_total
  FROM public.invoice_line_items
  WHERE invoice_id = p_invoice_id;

  UPDATE public.invoices
  SET total_amount = v_new_total
  WHERE id = p_invoice_id;

  RETURN jsonb_build_object(
    'success', true,
    'batch_number', v_batch_num,
    'unit_cost', v_unit_cost,
    'total_amount', v_new_total,
    'fefo_enforced', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.receive_stock_batch(
  p_item_id uuid,
  p_batch_number text,
  p_quantity int,
  p_expiry_date date
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_batch_id uuid;
  v_manila_today date := (now() AT TIME ZONE 'Asia/Manila')::date;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Received quantity must be greater than zero.';
  END IF;

  IF p_expiry_date IS NULL OR p_expiry_date < v_manila_today THEN
    RAISE EXCEPTION 'Cannot receive expired stock batch (expiry_date: %).', p_expiry_date;
  END IF;

  INSERT INTO public.inventory_batches (
    item_id, batch_number, quantity_remaining, expiry_date, received_date
  )
  VALUES (
    p_item_id,
    btrim(p_batch_number),
    p_quantity,
    p_expiry_date,
    v_manila_today
  )
  RETURNING id INTO v_batch_id;

  RETURN v_batch_id;
END;
$$;

REVOKE ALL ON FUNCTION public.dispense_item(text, uuid, int) FROM anon;
REVOKE ALL ON FUNCTION public.dispense_item_tenant(uuid, uuid, uuid, int) FROM anon;
REVOKE ALL ON FUNCTION public.get_expiring_batches(int) FROM anon;
REVOKE ALL ON FUNCTION public.get_low_stock_items() FROM anon;
REVOKE ALL ON FUNCTION public.receive_stock_batch(uuid, text, int, date) FROM anon;
REVOKE ALL ON FUNCTION public.schedule_vaccine_reminder(uuid, text, timestamptz) FROM anon;
REVOKE ALL ON FUNCTION public.schedule_bill_reminder(uuid) FROM anon;

GRANT EXECUTE ON FUNCTION public.dispense_item(text, uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispense_item_tenant(uuid, uuid, uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_expiring_batches(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_low_stock_items() TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_stock_batch(uuid, text, int, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_vaccine_reminder(uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_bill_reminder(uuid) TO authenticated;

COMMIT;
