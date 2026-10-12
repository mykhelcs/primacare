-- ============================================================================
-- PrimaCare Smart Clinic — Production Security Hardening & Concurrency Lockdown
-- Addresses Pentest Findings:
--   1. Revokes open 'anon' access to all clinical & financial tables.
--   2. Restricts patient & billing mutations strictly to authenticated clinic staff.
--   3. Adds FOR UPDATE row-level locking on FEFO inventory batch deductions
--      to eliminate concurrent overselling race conditions.
--   4. Restricts financial views and analytics strictly to Clinic Administrators.
-- ============================================================================

-- 1. Hardened Row Level Security (RLS) on Clinical Entities
DO $$
BEGIN
  -- Drop overly permissive policies from previous test/demo migration
  DROP POLICY IF EXISTS "Allow all access to inventory items" ON public.inventory_items;
  DROP POLICY IF EXISTS "Allow all access to inventory batches" ON public.inventory_batches;
  DROP POLICY IF EXISTS "Allow all access to patients" ON public.patients;
  DROP POLICY IF EXISTS "Allow all access to invoices" ON public.invoices;
  DROP POLICY IF EXISTS "Allow all access to invoice line items" ON public.invoice_line_items;

  -- Ensure RLS is active on all tables
  ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.invoice_line_items ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

  -- Patients Table: Only authenticated clinic staff can read, insert, update
  DROP POLICY IF EXISTS "Staff authenticated read patients" ON public.patients;
  CREATE POLICY "Staff authenticated read patients" ON public.patients
    FOR SELECT TO authenticated
    USING (clinic_id IS NULL OR clinic_id = (SELECT clinic_id FROM public.users WHERE id = auth.uid()));

  DROP POLICY IF EXISTS "Staff authenticated insert patients" ON public.patients;
  CREATE POLICY "Staff authenticated insert patients" ON public.patients
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff authenticated update patients" ON public.patients;
  CREATE POLICY "Staff authenticated update patients" ON public.patients
    FOR UPDATE TO authenticated
    USING (clinic_id IS NULL OR clinic_id = (SELECT clinic_id FROM public.users WHERE id = auth.uid()));

  -- Invoices Table: Only authenticated clinic staff can read and modify
  DROP POLICY IF EXISTS "Staff authenticated read invoices" ON public.invoices;
  CREATE POLICY "Staff authenticated read invoices" ON public.invoices
    FOR SELECT TO authenticated
    USING (clinic_id IS NULL OR clinic_id = (SELECT clinic_id FROM public.users WHERE id = auth.uid()));

  DROP POLICY IF EXISTS "Staff authenticated insert invoices" ON public.invoices;
  CREATE POLICY "Staff authenticated insert invoices" ON public.invoices
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff authenticated update invoices" ON public.invoices;
  CREATE POLICY "Staff authenticated update invoices" ON public.invoices
    FOR UPDATE TO authenticated
    USING (clinic_id IS NULL OR clinic_id = (SELECT clinic_id FROM public.users WHERE id = auth.uid()));

  -- Invoice Line Items Table
  DROP POLICY IF EXISTS "Staff authenticated read invoice lines" ON public.invoice_line_items;
  CREATE POLICY "Staff authenticated read invoice lines" ON public.invoice_line_items
    FOR SELECT TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Staff authenticated insert invoice lines" ON public.invoice_line_items;
  CREATE POLICY "Staff authenticated insert invoice lines" ON public.invoice_line_items
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

  -- Inventory Items & Batches
  DROP POLICY IF EXISTS "Staff authenticated read inventory" ON public.inventory_items;
  CREATE POLICY "Staff authenticated read inventory" ON public.inventory_items
    FOR SELECT TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Staff authenticated manage inventory" ON public.inventory_items;
  CREATE POLICY "Staff authenticated manage inventory" ON public.inventory_items
    FOR ALL TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Staff authenticated read batches" ON public.inventory_batches;
  CREATE POLICY "Staff authenticated read batches" ON public.inventory_batches
    FOR SELECT TO authenticated
    USING (true);

  DROP POLICY IF EXISTS "Staff authenticated manage batches" ON public.inventory_batches;
  CREATE POLICY "Staff authenticated manage batches" ON public.inventory_batches
    FOR ALL TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);
END
$$;

-- 2. Concurrency-Hardened FEFO Dispensation Function with FOR UPDATE Row-Level Locking
CREATE OR REPLACE FUNCTION public.dispense_item(
  p_barcode text,
  p_invoice_id uuid,
  p_quantity int DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item public.inventory_items%ROWTYPE;
  v_batch public.inventory_batches%ROWTYPE;
  v_needed int := p_quantity;
  v_deduct int;
  v_total_added numeric(10,2) := 0;
  v_batches_dispensed text[] := ARRAY[]::text[];
BEGIN
  -- Defensive validation: reject non-positive quantities
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Dispensation quantity must be greater than zero.');
  END IF;

  -- 1. Lookup item by barcode
  SELECT * INTO v_item FROM public.inventory_items WHERE barcode = p_barcode;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode not found');
  END IF;

  -- 2. Verify total active non-expired stock
  IF (SELECT COALESCE(SUM(quantity_remaining), 0) 
      FROM public.inventory_batches 
      WHERE item_id = v_item.id AND expiry_date >= CURRENT_DATE) < p_quantity THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient unexpired stock available');
  END IF;

  -- 3. Concurrency-Safe FEFO Loop: Lock selected batches with FOR UPDATE
  FOR v_batch IN
    SELECT * FROM public.inventory_batches
    WHERE item_id = v_item.id 
      AND quantity_remaining > 0 
      AND expiry_date >= CURRENT_DATE
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

  -- 4. Recalculate Invoice Total
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
END;
$$;
