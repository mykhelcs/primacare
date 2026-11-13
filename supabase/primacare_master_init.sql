-- ============================================================================
-- PrimaCare Smart Clinic — Unified One-Click Master Initialization & Seed Script
-- File: primacare_master_init.sql
-- Purpose: Stands up the complete production-hardened schema, RLS policies,
--          atomic FIFO/FEFO RPCs (with Asia/Manila timezone accuracy),
--          analytics views, and fresh relative-date seed data in a single run.
-- ============================================================================

BEGIN;

-- Ensure cryptographic UUID generation and Asia/Manila timezone alignment
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
SET TIME ZONE 'Asia/Manila';

-- ============================================================================
-- SECTION 1: SCHEMA & TABLE CREATIONS
-- ============================================================================

-- 1.1 Clinics Table (Multi-Tenant Root)
CREATE TABLE IF NOT EXISTS public.clinics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text UNIQUE NOT NULL,
  address text,
  contact_number text,
  tin_number text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- 1.2 Users Profile Table (linked to auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  role text CHECK (role IN ('admin', 'nurse', 'doctor')) DEFAULT 'nurse',
  clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001',
  created_at timestamptz DEFAULT now()
);

-- 1.3 Patients Table (with extended clinical columns)
CREATE TABLE IF NOT EXISTS public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL,
  date_of_birth date,
  contact_number text,
  email text,
  sex text,
  allergies text DEFAULT 'None recorded',
  address text,
  emergency_contact text,
  clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS sex text,
  ADD COLUMN IF NOT EXISTS allergies text DEFAULT 'None recorded',
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS emergency_contact text,
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

-- 1.4 Inventory Items Table
CREATE TABLE IF NOT EXISTS public.inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  barcode text UNIQUE,
  unit text DEFAULT 'piece',
  unit_cost numeric(10,2) NOT NULL DEFAULT 0.00,
  category text DEFAULT 'consumable',
  reorder_level int DEFAULT 10,
  clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

-- 1.5 Inventory Batches Table (FIFO/FEFO tracked by received_date and expiry_date)
CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  batch_number text NOT NULL,
  quantity_remaining int NOT NULL CHECK (quantity_remaining >= 0),
  expiry_date date NOT NULL,
  received_date date DEFAULT (now() AT TIME ZONE 'Asia/Manila')::date,
  clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.inventory_batches
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

-- 1.6 Invoices Table (includes Philippine Statutory Senior/PWD Discount & Settlement Audit columns)
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  created_by uuid REFERENCES public.users(id),
  status text DEFAULT 'open' CHECK (status IN ('open', 'paid', 'partial')),
  total_amount numeric(10,2) DEFAULT 0.00,
  discount_type text DEFAULT 'none' CHECK (discount_type IN ('none', 'senior', 'pwd', 'custom')),
  discount_percentage numeric(5,2) DEFAULT 0.00,
  discount_id_number text,
  payment_method text,
  paid_at timestamptz,
  clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS discount_type text DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS discount_percentage numeric(5,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS discount_id_number text,
  ADD COLUMN IF NOT EXISTS payment_method text,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

-- 1.7 Invoice Line Items Table
CREATE TABLE IF NOT EXISTS public.invoice_line_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  inventory_batch_id uuid REFERENCES public.inventory_batches(id),
  item_name text NOT NULL,
  quantity int NOT NULL CHECK (quantity > 0),
  unit_cost numeric(10,2) NOT NULL,
  line_total numeric(10,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  created_at timestamptz DEFAULT now()
);

-- 1.8 Notifications Queue Table
CREATE TABLE IF NOT EXISTS public.notifications_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid REFERENCES public.patients(id) ON DELETE CASCADE,
  type text CHECK (type IN ('vaccine_reminder', 'follow_up', 'bill_reminder', 'expiry_alert')),
  message text NOT NULL,
  scheduled_for timestamptz,
  sent_at timestamptz,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.notifications_queue
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.notifications_queue
  DROP CONSTRAINT IF EXISTS notifications_queue_type_check;
ALTER TABLE public.notifications_queue
  ADD CONSTRAINT notifications_queue_type_check
  CHECK (type IN ('vaccine_reminder', 'follow_up', 'bill_reminder', 'expiry_alert'));

-- 1.9 Performance Indexes
CREATE INDEX IF NOT EXISTS idx_patients_clinic ON public.patients(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_clinic ON public.inventory_items(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_barcode ON public.inventory_items(barcode);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_clinic ON public.inventory_batches(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_item_expiry ON public.inventory_batches(item_id, expiry_date, received_date);
CREATE INDEX IF NOT EXISTS idx_invoices_clinic ON public.invoices(clinic_id);
CREATE INDEX IF NOT EXISTS idx_notifications_clinic ON public.notifications_queue(clinic_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status_sched ON public.notifications_queue(status, scheduled_for);

-- 1.10 Reporting & Analytics Views (Security Invoker + Admin-restricted + Clinic-scoped)
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

-- ============================================================================
-- SECTION 2: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

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
  -- Clean up any legacy policies before recreating idempotently
  DROP POLICY IF EXISTS "Allow all access to inventory items" ON public.inventory_items;
  DROP POLICY IF EXISTS "Allow all access to inventory batches" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Allow all access to patients" ON public.patients;
  DROP POLICY IF EXISTS "Allow all access to invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Allow all access to invoice line items" ON public.invoice_line_items;

  -- Clinics Policies (Authenticated Staff Only)
  DROP POLICY IF EXISTS "Allow authenticated staff to read clinics" ON public.clinics;
  CREATE POLICY "Allow authenticated staff to read clinics"
    ON public.clinics FOR SELECT
    TO authenticated
    USING (auth.uid() IS NOT NULL);

  -- Users Policies
  DROP POLICY IF EXISTS "Users read own profile" ON public.users;
  CREATE POLICY "Users read own profile"
    ON public.users FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

  -- Patients Policies (Authenticated Staff Only)
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

  -- Inventory Items Policies (Authenticated Staff Only)
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

  -- Inventory Batches Policies (Authenticated Staff Only)
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

  -- Invoices Policies (Authenticated Staff Only)
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

  -- Invoice Line Items Policies (Authenticated Staff Only)
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

  -- Notifications Queue Policies (Authenticated Staff Only)
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

-- Sync new auth.users accounts into public.users with authoritative clinic role
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

-- ============================================================================
-- SECTION 3: STORED PROCEDURES & ATOMIC RPC FUNCTIONS
-- ============================================================================

-- 3.1 Atomic Concurrency-Safe FIFO/FEFO Dispensation RPC (Asia/Manila Timezone Aware)
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

  -- 1. Defensive validation: reject non-positive quantities or empty barcodes
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Dispensation quantity must be greater than zero.');
  END IF;

  IF p_barcode IS NULL OR btrim(p_barcode) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode cannot be empty.');
  END IF;

  -- 2. Lookup item by barcode
  SELECT * INTO v_item FROM public.inventory_items WHERE barcode = btrim(p_barcode);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode not found in clinic formulary.');
  END IF;

  -- 3. Verify target invoice exists and is not already settled
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

  -- 3b. Clinical Services do not draw from physical inventory batches
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

  -- 4. Verify total active non-expired stock (strictly evaluated in Asia/Manila date)
  IF (SELECT COALESCE(SUM(quantity_remaining), 0)
      FROM public.inventory_batches
      WHERE item_id = v_item.id AND expiry_date >= v_manila_today) < p_quantity THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient unexpired stock available for ' || v_item.name || '.');
  END IF;

  -- 5. Concurrency-Safe Atomic FIFO/FEFO Loop with FOR UPDATE Row-Level Locking
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

  -- Verify complete fulfillment in case of concurrent race condition
  IF v_needed > 0 THEN
    RAISE EXCEPTION 'Concurrent stock depletion detected for %', v_item.name;
  END IF;

  -- 6. Update Invoice Total Atomically
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

-- 3.2 Multi-Tenant Isolated Dispensation RPC
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

-- 3.3 Expiring Batches Watcher (Asia/Manila Date Boundary)
CREATE OR REPLACE FUNCTION public.get_expiring_batches(days_ahead int DEFAULT 30)
RETURNS TABLE (
  batch_id uuid,
  item_name text,
  batch_number text,
  quantity_remaining int,
  expiry_date date,
  days_remaining int
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    b.id AS batch_id,
    i.name AS item_name,
    b.batch_number,
    b.quantity_remaining,
    b.expiry_date,
    (b.expiry_date - (now() AT TIME ZONE 'Asia/Manila')::date)::int AS days_remaining
  FROM public.inventory_batches b
  JOIN public.inventory_items i ON b.item_id = i.id
  WHERE b.quantity_remaining > 0
    AND b.expiry_date BETWEEN (now() AT TIME ZONE 'Asia/Manila')::date
                          AND ((now() AT TIME ZONE 'Asia/Manila')::date + days_ahead)
  ORDER BY b.expiry_date ASC;
$$;

-- 3.4 Low Stock Items Watcher (Asia/Manila Date Boundary)
CREATE OR REPLACE FUNCTION public.get_low_stock_items()
RETURNS TABLE (
  item_id uuid,
  name text,
  category text,
  total_stock bigint,
  reorder_level int
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    i.id AS item_id,
    i.name,
    i.category,
    COALESCE(SUM(b.quantity_remaining), 0)::bigint AS total_stock,
    i.reorder_level
  FROM public.inventory_items i
  LEFT JOIN public.inventory_batches b
    ON i.id = b.item_id
   AND b.expiry_date >= (now() AT TIME ZONE 'Asia/Manila')::date
  GROUP BY i.id, i.name, i.category, i.reorder_level
  HAVING COALESCE(SUM(b.quantity_remaining), 0) <= i.reorder_level
  ORDER BY total_stock ASC;
$$;

-- 3.5 Receive New Inbound Stock Batch
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

-- 3.6 Schedule Vaccine Reminder (Formatted in Asia/Manila Time)
CREATE OR REPLACE FUNCTION public.schedule_vaccine_reminder(
  p_patient_id uuid,
  p_vaccine_name text,
  p_due_date timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_queue_id uuid;
BEGIN
  INSERT INTO public.notifications_queue (patient_id, type, message, scheduled_for, status)
  VALUES (
    p_patient_id,
    'vaccine_reminder',
    'Reminder from PrimaCare: Upcoming ' || p_vaccine_name || ' is scheduled for ' ||
      to_char(p_due_date AT TIME ZONE 'Asia/Manila', 'Mon DD, YYYY') || '. Please visit the clinic.',
    p_due_date,
    'pending'
  )
  RETURNING id INTO v_queue_id;

  RETURN v_queue_id;
END;
$$;

-- 3.7 Schedule Bill Reminder for Open Invoices
CREATE OR REPLACE FUNCTION public.schedule_bill_reminder(p_invoice_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_inv public.invoices%ROWTYPE;
  v_queue_id uuid;
BEGIN
  SELECT * INTO v_inv FROM public.invoices WHERE id = p_invoice_id AND status = 'open';
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.notifications_queue (patient_id, type, message, scheduled_for, status)
  VALUES (
    v_inv.patient_id,
    'bill_reminder',
    'PrimaCare Statement: Invoice #' || p_invoice_id || ' with balance of ₱' || v_inv.total_amount || ' is awaiting settlement.',
    now() + interval '1 day',
    'pending'
  )
  RETURNING id INTO v_queue_id;

  RETURN v_queue_id;
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

-- ============================================================================
-- SECTION 4: SEED DATA INSERTION (RELATIVE DATES FOR ALWAYS-FRESH TESTING)
-- ============================================================================

-- 4.1 Seed Primary Clinic Branches
INSERT INTO public.clinics (id, name, code, address, contact_number, tin_number)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'PrimaCare Central Clinic', 'PC-CENTRAL', '123 Medical Center Blvd, Metro Manila', '+63 2 8123 4567', '123-456-789-000'),
  ('00000000-0000-0000-0000-000000000002', 'PrimaCare North Branch', 'PC-NORTH', '45 North Ave, Quezon City', '+63 2 8987 6543', '123-456-789-001')
ON CONFLICT (id) DO NOTHING;

-- 4.2 Seed Core Clinical Formulary (Vaccines, Consumables, Pharmaceuticals, Services)
INSERT INTO public.inventory_items (name, barcode, unit, unit_cost, category, reorder_level, clinic_id)
VALUES
  -- Vaccines
  ('Hepatitis B Pediatric Vaccine', '4800016552011', 'vial', 450.00, 'Vaccines', 10, '00000000-0000-0000-0000-000000000001'),
  ('MMR Pediatric Vaccine', '4800016552012', 'vial', 720.00, 'Vaccines', 10, '00000000-0000-0000-0000-000000000001'),
  ('Pentavalent (DTP-HepB-Hib) Vaccine', '4800016552013', 'vial', 850.00, 'Vaccines', 15, '00000000-0000-0000-0000-000000000001'),
  ('BCG Tuberculosis Vaccine', '4800016552014', 'ampoule', 380.00, 'Vaccines', 10, '00000000-0000-0000-0000-000000000001'),
  ('Rotavirus Oral Vaccine', '4800016552016', 'tube', 1250.00, 'Vaccines', 8, '00000000-0000-0000-0000-000000000001'),
  ('Inactivated Influenza Vaccine (Quadrivalent)', '4800016552017', 'prefilled syringe', 650.00, 'Vaccines', 20, '00000000-0000-0000-0000-000000000001'),
  -- Consumables
  ('Disposable Syringe 3ml with Needle', '4800016552022', 'pcs', 25.00, 'Consumables', 50, '00000000-0000-0000-0000-000000000001'),
  ('Disposable Syringe 1ml Tuberculin', '4800016552023', 'pcs', 20.00, 'Consumables', 50, '00000000-0000-0000-0000-000000000001'),
  ('Sterile Alcohol Swabs (70% Isopropyl)', '4800016552025', 'box', 110.00, 'Consumables', 10, '00000000-0000-0000-0000-000000000001'),
  ('Sterile Gauze Sponges 2x2 (Pack of 100)', '4800016552026', 'pack', 140.00, 'Consumables', 10, '00000000-0000-0000-0000-000000000001'),
  ('Examination Latex Gloves Medium', '4800016552027', 'box', 280.00, 'Consumables', 5, '00000000-0000-0000-0000-000000000001'),
  -- Pharmaceuticals
  ('Paracetamol 500mg Tablets', '4800016552033', 'tabs', 5.50, 'Pharmaceuticals', 100, '00000000-0000-0000-0000-000000000001'),
  ('Paracetamol 120mg/5ml Pediatric Drops (60ml)', '4800016552034', 'bottle', 85.00, 'Pharmaceuticals', 20, '00000000-0000-0000-0000-000000000001'),
  ('Amoxicillin 500mg Capsules', '4800016552035', 'caps', 8.00, 'Pharmaceuticals', 100, '00000000-0000-0000-0000-000000000001'),
  ('Amoxicillin 250mg/5ml Suspension (60ml)', '4800016552036', 'bottle', 95.00, 'Pharmaceuticals', 15, '00000000-0000-0000-0000-000000000001'),
  ('Oral Rehydration Salts (Hydrite Sachets)', '4800016552037', 'sachet', 15.00, 'Pharmaceuticals', 50, '00000000-0000-0000-0000-000000000001'),
  ('Cetirizine 10mg Film-Coated Tablets', '4800016552038', 'tabs', 12.00, 'Pharmaceuticals', 50, '00000000-0000-0000-0000-000000000001'),
  -- Clinical Services
  ('General Medical Consultation', 'SRV-001', 'service', 500.00, 'Services', 0, '00000000-0000-0000-0000-000000000001'),
  ('Pediatric Well-Baby & Immunization Exam', 'SRV-002', 'service', 600.00, 'Services', 0, '00000000-0000-0000-0000-000000000001'),
  ('Nebulization Session (with Salbutamol)', 'SRV-003', 'procedure', 250.00, 'Services', 0, '00000000-0000-0000-0000-000000000001'),
  ('Minor Wound Dressing & Antiseptic Care', 'SRV-004', 'procedure', 350.00, 'Services', 0, '00000000-0000-0000-0000-000000000001')
ON CONFLICT (barcode) DO UPDATE
SET
  name = EXCLUDED.name,
  unit = EXCLUDED.unit,
  unit_cost = EXCLUDED.unit_cost,
  category = EXCLUDED.category,
  reorder_level = EXCLUDED.reorder_level;

-- 4.3 Seed Inventory Batches, Patients, Open Invoice, and Notifications Queue Using Relative Dates
DO $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Manila')::date;
  v_hepb_id uuid;
  v_mmr_id uuid;
  v_penta_id uuid;
  v_flu_id uuid;
  v_syr3_id uuid;
  v_para_id uuid;
  v_amox_id uuid;
  v_juan_id uuid;
  v_maria_id uuid;
  v_invoice_id uuid;
BEGIN
  SELECT id INTO v_hepb_id FROM public.inventory_items WHERE barcode = '4800016552011';
  SELECT id INTO v_mmr_id FROM public.inventory_items WHERE barcode = '4800016552012';
  SELECT id INTO v_penta_id FROM public.inventory_items WHERE barcode = '4800016552013';
  SELECT id INTO v_flu_id FROM public.inventory_items WHERE barcode = '4800016552017';
  SELECT id INTO v_syr3_id FROM public.inventory_items WHERE barcode = '4800016552022';
  SELECT id INTO v_para_id FROM public.inventory_items WHERE barcode = '4800016552033';
  SELECT id INTO v_amox_id FROM public.inventory_items WHERE barcode = '4800016552035';

  -- Seed batches only if inventory_batches is empty so re-running does not duplicate batches
  IF NOT EXISTS (SELECT 1 FROM public.inventory_batches LIMIT 1) THEN
    INSERT INTO public.inventory_batches (item_id, batch_number, quantity_remaining, expiry_date, received_date, clinic_id)
    VALUES
      -- Hep B Batch 1 (Near expiry: +18 days, older received date: -60 days -> dispensed first by FIFO/FEFO)
      (v_hepb_id, 'HB-LOT-01', 12, v_today + 18, v_today - 60, '00000000-0000-0000-0000-000000000001'),
      -- Hep B Batch 2 (Later expiry: +180 days, newer received date: -10 days)
      (v_hepb_id, 'HB-LOT-02', 20, v_today + 180, v_today - 10, '00000000-0000-0000-0000-000000000001'),
      -- MMR Batch (Near expiry: +26 days, low stock: 6 remaining)
      (v_mmr_id, 'MMR-LOT-09', 6, v_today + 26, v_today - 45, '00000000-0000-0000-0000-000000000001'),
      -- Pentavalent Batch (+150 days)
      (v_penta_id, 'PV-LOT-11', 18, v_today + 150, v_today - 20, '00000000-0000-0000-0000-000000000001'),
      -- Influenza Batch (+300 days)
      (v_flu_id, 'FLU-LOT-22', 35, v_today + 300, v_today - 15, '00000000-0000-0000-0000-000000000001'),
      -- Syringe 3ml Batch (+365 days)
      (v_syr3_id, 'SYR-LOT-11', 120, v_today + 365, v_today - 30, '00000000-0000-0000-0000-000000000001'),
      -- Paracetamol 500mg Batch (+240 days)
      (v_para_id, 'PARA-LOT-04', 250, v_today + 240, v_today - 25, '00000000-0000-0000-0000-000000000001'),
      -- Amoxicillin 500mg Batch (+210 days)
      (v_amox_id, 'AMOX-LOT-08', 180, v_today + 210, v_today - 12, '00000000-0000-0000-0000-000000000001');
  END IF;

  -- Seed Initial Clinical Patients if empty
  IF NOT EXISTS (SELECT 1 FROM public.patients LIMIT 1) THEN
    INSERT INTO public.patients (full_name, date_of_birth, contact_number, email, sex, allergies, address, emergency_contact, clinic_id)
    VALUES
      ('Juan Dela Cruz', '1990-05-15', '+63 917 123 4567', 'juan@example.ph', 'Male', 'None recorded', 'Makati City, Metro Manila', '+63 917 000 1111 (Spouse)', '00000000-0000-0000-0000-000000000001'),
      ('Maria Santos', '1985-11-02', '+63 928 987 6543', 'maria@example.ph', 'Female', 'Penicillin', 'Quezon City, Metro Manila', '+63 928 000 2222 (Sibling)', '00000000-0000-0000-0000-000000000001'),
      ('Roberto Lim', '1958-08-23', '+63 905 456 7890', 'roberto@example.ph', 'Male', 'Aspirin', 'Pasig City, Metro Manila', '+63 905 000 3333 (Child)', '00000000-0000-0000-0000-000000000001'),
      ('Elena Garcia', '1998-01-11', '+63 919 234 5678', 'elena@example.ph', 'Female', 'None recorded', 'Taguig City, Metro Manila', '+63 919 000 4444 (Parent)', '00000000-0000-0000-0000-000000000001');
  END IF;

  SELECT id INTO v_juan_id FROM public.patients WHERE full_name = 'Juan Dela Cruz' LIMIT 1;
  SELECT id INTO v_maria_id FROM public.patients WHERE full_name = 'Maria Santos' LIMIT 1;

  -- Seed Active Open Invoice for Juan Dela Cruz if no open invoice exists
  IF v_juan_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.invoices WHERE patient_id = v_juan_id) THEN
    INSERT INTO public.invoices (patient_id, status, total_amount, discount_type, discount_percentage, clinic_id)
    VALUES (v_juan_id, 'open', 500.00, 'none', 0.00, '00000000-0000-0000-0000-000000000001')
    RETURNING id INTO v_invoice_id;

    INSERT INTO public.invoice_line_items (invoice_id, item_name, quantity, unit_cost)
    VALUES (v_invoice_id, 'General Medical Consultation', 1, 500.00);
  END IF;

  -- Seed Notifications Queue using relative timestamps if empty
  IF v_juan_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.notifications_queue LIMIT 1) THEN
    INSERT INTO public.notifications_queue (patient_id, type, message, scheduled_for, status, clinic_id)
    VALUES
      (
        v_juan_id,
        'vaccine_reminder',
        'Reminder from PrimaCare: Upcoming Hepatitis B Booster Dose is scheduled for ' ||
          to_char((now() + interval '3 days') AT TIME ZONE 'Asia/Manila', 'Mon DD, YYYY') || '. Please visit the clinic.',
        now() + interval '3 days',
        'pending',
        '00000000-0000-0000-0000-000000000001'
      ),
      (
        COALESCE(v_maria_id, v_juan_id),
        'follow_up',
        'PrimaCare Follow-Up: Please remember your scheduled pediatric wellness checkup tomorrow.',
        now() - interval '1 hour',
        'pending',
        '00000000-0000-0000-0000-000000000001'
      );
  END IF;
END
$$;

COMMIT;
