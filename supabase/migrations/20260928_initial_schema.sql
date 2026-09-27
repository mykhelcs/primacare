-- PrimaCare Smart Clinic MVP Schema
-- Target: Supabase Postgres

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Users Profile Table (linked to auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  role text CHECK (role IN ('admin', 'nurse', 'doctor')) DEFAULT 'nurse',
  created_at timestamptz DEFAULT now()
);

-- 2. Patients Table
CREATE TABLE IF NOT EXISTS public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL,
  date_of_birth date,
  contact_number text,
  email text,
  created_at timestamptz DEFAULT now()
);

-- 3. Inventory Items
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

-- 4. Inventory Batches (FIFO enforced by received_date ASC)
CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  batch_number text NOT NULL,
  quantity_remaining int NOT NULL CHECK (quantity_remaining >= 0),
  expiry_date date NOT NULL,
  received_date date DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

-- 5. Invoices
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  created_by uuid REFERENCES public.users(id),
  status text DEFAULT 'open' CHECK (status IN ('open', 'paid', 'partial')),
  total_amount numeric(10,2) DEFAULT 0.00,
  created_at timestamptz DEFAULT now()
);

-- 6. Invoice Line Items
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

-- 7. Notifications Queue
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

-- 8. Stored Procedure: dispense_item (FIFO dispensation)
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
  -- Lookup item
  SELECT * INTO v_item FROM public.inventory_items WHERE barcode = p_barcode;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Item barcode not found');
  END IF;

  -- Verify total stock available
  IF (SELECT COALESCE(SUM(quantity_remaining), 0) FROM public.inventory_batches WHERE item_id = v_item.id AND expiry_date >= CURRENT_DATE) < p_quantity THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient stock for this item');
  END IF;

  -- Deduct batches using FIFO (earliest received_date first)
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

  -- Update invoice total
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
