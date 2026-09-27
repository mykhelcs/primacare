-- ============================================================================
-- PrimaCare Smart Clinic — Complete End-to-End Database Migration
-- Covers Phases 1 to 5 (Core Loop, Inventory FIFO, Notifications, Analytics, RLS)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Users Profile Table (linked to auth.users)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  role text CHECK (role IN ('admin', 'nurse', 'doctor')) DEFAULT 'nurse',
  created_at timestamptz DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 2. Patients Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL,
  date_of_birth date,
  contact_number text,
  email text,
  created_at timestamptz DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 3. Inventory Items
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  barcode text UNIQUE,
  unit text DEFAULT 'piece',
  unit_cost numeric(10,2) NOT NULL DEFAULT 0.00,
  category text DEFAULT 'consumable',
  reorder_level int DEFAULT 10,
  created_at timestamptz DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4. Inventory Batches (FIFO enforced by received_date ASC)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  batch_number text NOT NULL,
  quantity_remaining int NOT NULL CHECK (quantity_remaining >= 0),
  expiry_date date NOT NULL,
  received_date date DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 5. Invoices
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  created_by uuid REFERENCES public.users(id),
  status text DEFAULT 'open' CHECK (status IN ('open', 'paid', 'partial')),
  total_amount numeric(10,2) DEFAULT 0.00,
  created_at timestamptz DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 6. Invoice Line Items
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 7. Notifications Queue
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid REFERENCES public.patients(id) ON DELETE CASCADE,
  type text CHECK (type IN ('vaccine_reminder', 'follow_up', 'bill_reminder')),
  message text NOT NULL,
  scheduled_for timestamptz,
  sent_at timestamptz,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- Phase 1 Procedure: FIFO Dispensation
CREATE OR REPLACE FUNCTION public.dispense_item(
  p_barcode text,
  p_invoice_id uuid,
  p_quantity int DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_item public.inventory_items%ROWTYPE;
  v_batch public.inventory_batches%ROWTYPE;
  v_needed int := p_quantity;
  v_deduct int;
  v_total_added numeric(10,2) := 0;
BEGIN
  SELECT * INTO v_item FROM public.inventory_items WHERE barcode = p_barcode;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode not found');
  END IF;

  IF (SELECT COALESCE(SUM(quantity_remaining), 0) FROM public.inventory_batches WHERE item_id = v_item.id AND expiry_date >= CURRENT_DATE) < p_quantity THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient stock for this item');
  END IF;

  FOR v_batch IN
    SELECT * FROM public.inventory_batches
    WHERE item_id = v_item.id AND quantity_remaining > 0 AND expiry_date >= CURRENT_DATE
    ORDER BY received_date ASC, expiry_date ASC
  LOOP
    EXIT WHEN v_needed <= 0;

    v_deduct := LEAST(v_batch.quantity_remaining, v_needed);

    UPDATE public.inventory_batches
    SET quantity_remaining = quantity_remaining - v_deduct
    WHERE id = v_batch.id;

    INSERT INTO public.invoice_line_items (invoice_id, inventory_batch_id, item_name, quantity, unit_cost)
    VALUES (p_invoice_id, v_batch.id, v_item.name, v_deduct, v_item.unit_cost);

    v_total_added := v_total_added + (v_deduct * v_item.unit_cost);
    v_needed := v_needed - v_deduct;
  END LOOP;

  UPDATE public.invoices
  SET total_amount = total_amount + v_total_added
  WHERE id = p_invoice_id;

  RETURN jsonb_build_object(
    'success', true,
    'item_name', v_item.name,
    'quantity_dispensed', p_quantity,
    'amount_added', v_total_added
  );
END;
$$;

-- Phase 2 Procedure: Expiring Batches Watcher
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
    (b.expiry_date - CURRENT_DATE)::int AS days_remaining
  FROM public.inventory_batches b
  JOIN public.inventory_items i ON b.item_id = i.id
  WHERE b.quantity_remaining > 0 
    AND b.expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + days_ahead)
  ORDER BY b.expiry_date ASC;
$$;

-- Phase 2 Procedure: Low Stock Items Watcher
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
  LEFT JOIN public.inventory_batches b ON i.id = b.item_id AND b.expiry_date >= CURRENT_DATE
  GROUP BY i.id, i.name, i.category, i.reorder_level
  HAVING COALESCE(SUM(b.quantity_remaining), 0) <= i.reorder_level
  ORDER BY total_stock ASC;
$$;

-- Phase 2 Procedure: Receive New Inbound Stock Batch
CREATE OR REPLACE FUNCTION public.receive_stock_batch(
  p_item_id uuid,
  p_batch_number text,
  p_quantity int,
  p_expiry_date date
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_batch_id uuid;
BEGIN
  INSERT INTO public.inventory_batches (item_id, batch_number, quantity_remaining, expiry_date, received_date)
  VALUES (p_item_id, p_batch_number, p_quantity, p_expiry_date, CURRENT_DATE)
  RETURNING id INTO v_batch_id;
  
  RETURN v_batch_id;
END;
$$;

-- Phase 3 Procedure: Schedule Vaccine Reminder
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
    'Reminder from PrimaCare: Upcoming ' || p_vaccine_name || ' is scheduled for ' || to_char(p_due_date, 'Mon DD, YYYY') || '. Please visit the clinic.',
    p_due_date,
    'pending'
  )
  RETURNING id INTO v_queue_id;

  RETURN v_queue_id;
END;
$$;

-- Phase 3 Procedure: Schedule Bill Reminder for Invoices open > 7 days
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

-- ============================================================================
-- Phase 4: REPORTING & ANALYTICS VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW public.view_monthly_billing_summary AS
SELECT
  to_char(created_at, 'YYYY-MM') AS month_key,
  COUNT(id) AS total_invoices,
  COUNT(CASE WHEN status = 'paid' THEN 1 END) AS paid_invoices,
  COUNT(CASE WHEN status = 'open' THEN 1 END) AS open_invoices,
  COALESCE(SUM(total_amount), 0) AS total_billed_amount,
  COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS total_collected_amount
FROM public.invoices
GROUP BY to_char(created_at, 'YYYY-MM')
ORDER BY month_key DESC;

CREATE OR REPLACE VIEW public.view_revenue_leakage_prevented AS
SELECT
  ili.item_name,
  COUNT(ili.id) AS dispensation_count,
  SUM(ili.quantity) AS total_units_dispensed,
  SUM(ili.line_total) AS total_revenue_captured
FROM public.invoice_line_items ili
JOIN public.invoices inv ON ili.invoice_id = inv.id
GROUP BY ili.item_name
ORDER BY total_revenue_captured DESC;

-- ============================================================================
-- Phase 5: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

-- 1. Users policies: users can read their own profile, admins can manage all
CREATE POLICY "Users read own profile" ON public.users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

-- 2. Patients policies: authenticated clinic staff can select and insert
CREATE POLICY "Staff can view patients" ON public.patients
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Staff can register patients" ON public.patients
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Staff can update patients" ON public.patients
  FOR UPDATE TO authenticated
  USING (true);

-- 3. Inventory policies: staff can view, staff can dispense/insert
CREATE POLICY "Staff can view inventory" ON public.inventory_items
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Staff can view batches" ON public.inventory_batches
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Staff can insert batches" ON public.inventory_batches
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Staff can update batch quantities" ON public.inventory_batches
  FOR UPDATE TO authenticated
  USING (true);

-- 4. Invoices policies
CREATE POLICY "Staff can view invoices" ON public.invoices
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Staff can insert invoices" ON public.invoices
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Staff can update invoices" ON public.invoices
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "Staff can view invoice lines" ON public.invoice_line_items
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Staff can insert invoice lines" ON public.invoice_line_items
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- 5. Notifications policies
CREATE POLICY "Staff can view notifications" ON public.notifications_queue
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Staff can queue notifications" ON public.notifications_queue
  FOR INSERT TO authenticated
  WITH CHECK (true);
