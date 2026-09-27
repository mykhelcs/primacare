-- ============================================================================
-- PrimaCare Smart Clinic — Multi-Tenancy Architecture Migration (clinic_id)
-- Isolates all clinical data across independent clinic branches / organizations.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Clinics Table
-- ----------------------------------------------------------------------------
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

-- Seed Default Primary Clinics
INSERT INTO public.clinics (id, name, code, address, contact_number, tin_number)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'PrimaCare Central Clinic', 'PC-CENTRAL', '123 Medical Center Blvd, Metro Manila', '+63 2 8123 4567', '123-456-789-000'),
  ('00000000-0000-0000-0000-000000000002', 'PrimaCare North Branch', 'PC-NORTH', '45 North Ave, Quezon City', '+63 2 8987 6543', '123-456-789-001')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. Add clinic_id to All Relational Tables
-- ----------------------------------------------------------------------------
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.patients 
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.inventory_items 
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.inventory_batches 
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.invoices 
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

ALTER TABLE public.notifications_queue 
  ADD COLUMN IF NOT EXISTS clinic_id uuid REFERENCES public.clinics(id) DEFAULT '00000000-0000-0000-0000-000000000001';

-- Indexes for Multi-Tenant Query Performance
CREATE INDEX IF NOT EXISTS idx_patients_clinic ON public.patients(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_clinic ON public.inventory_items(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_clinic ON public.inventory_batches(clinic_id);
CREATE INDEX IF NOT EXISTS idx_invoices_clinic ON public.invoices(clinic_id);
CREATE INDEX IF NOT EXISTS idx_notifications_clinic ON public.notifications_queue(clinic_id);

-- ----------------------------------------------------------------------------
-- 3. Multi-Tenant Stored Procedures (Tenant Isolated)
-- ----------------------------------------------------------------------------

-- A. Tenant-Isolated Dispense Item (FIFO)
CREATE OR REPLACE FUNCTION public.dispense_item_tenant(
  p_clinic_id uuid,
  p_invoice_id uuid,
  p_item_id uuid,
  p_quantity int
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_batch_id uuid;
  v_batch_num text;
  v_unit_cost numeric(10,2);
  v_item_name text;
  v_rem int;
  v_line_id uuid;
  v_new_total numeric(10,2);
BEGIN
  -- Verify item exists in clinic
  SELECT name, unit_cost INTO v_item_name, v_unit_cost
  FROM public.inventory_items
  WHERE id = p_item_id AND (clinic_id = p_clinic_id OR clinic_id IS NULL);

  IF v_item_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found in current clinic.');
  END IF;

  -- Select earliest received non-expired batch with available stock in current clinic
  SELECT id, batch_number, quantity_remaining
  INTO v_batch_id, v_batch_num, v_rem
  FROM public.inventory_batches
  WHERE item_id = p_item_id 
    AND (clinic_id = p_clinic_id OR clinic_id IS NULL)
    AND quantity_remaining >= p_quantity
    AND expiry_date >= CURRENT_DATE
  ORDER BY received_date ASC, expiry_date ASC
  LIMIT 1
  FOR UPDATE;

  IF v_batch_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient stock or batch expired for this clinic.');
  END IF;

  -- Deduct inventory
  UPDATE public.inventory_batches
  SET quantity_remaining = quantity_remaining - p_quantity
  WHERE id = v_batch_id;

  -- Insert Line Item
  INSERT INTO public.invoice_line_items (
    invoice_id, inventory_batch_id, item_name, quantity, unit_cost
  ) VALUES (
    p_invoice_id, v_batch_id, v_item_name, p_quantity, v_unit_cost
  ) RETURNING id INTO v_line_id;

  -- Recalculate invoice total
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
    'line_item_id', v_line_id
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Multi-Tenant Row Level Security Policies
-- ----------------------------------------------------------------------------
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated staff to read clinics"
  ON public.clinics FOR SELECT
  TO authenticated
  USING (true);

-- End of Multi-Tenancy Migration
