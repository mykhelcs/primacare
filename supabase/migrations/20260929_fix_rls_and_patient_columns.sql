-- ============================================================================
-- PrimaCare Migration: Add Clinical Patient Columns and Complete RLS Policies
-- Solves:
--   1. PostgrestException 42501 (RLS insert policy on inventory_items / batches)
--   2. 400 Bad Request on patients table (missing sex, allergies, address, etc.)
-- ============================================================================

-- 1. Ensure Extended Patient Columns Exist
ALTER TABLE public.patients 
  ADD COLUMN IF NOT EXISTS sex text,
  ADD COLUMN IF NOT EXISTS allergies text DEFAULT 'None recorded',
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS emergency_contact text;

-- 2. Ensure Proper RLS Policies for inventory_items (Allow Anon and Authenticated for Demo/Clinic Operations)
DO $$
BEGIN
  -- Enable RLS
  ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.invoice_line_items ENABLE ROW LEVEL SECURITY;

  -- Inventory Items Policies
  DROP POLICY IF EXISTS "Allow all access to inventory items" ON public.inventory_items;
  CREATE POLICY "Allow all access to inventory items" ON public.inventory_items
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

  -- Inventory Batches Policies
  DROP POLICY IF EXISTS "Allow all access to inventory batches" ON public.inventory_batches;
  CREATE POLICY "Allow all access to inventory batches" ON public.inventory_batches
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

  -- Patients Policies
  DROP POLICY IF EXISTS "Allow all access to patients" ON public.patients;
  CREATE POLICY "Allow all access to patients" ON public.patients
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

  -- Invoices Policies
  DROP POLICY IF EXISTS "Allow all access to invoices" ON public.invoices;
  CREATE POLICY "Allow all access to invoices" ON public.invoices
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

  -- Invoice Line Items Policies
  DROP POLICY IF EXISTS "Allow all access to invoice line items" ON public.invoice_line_items;
  CREATE POLICY "Allow all access to invoice line items" ON public.invoice_line_items
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);
END
$$;
