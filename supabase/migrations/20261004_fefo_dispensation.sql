-- ============================================================================
-- PrimaCare Smart Clinic — FEFO (First Expired, First Out) Dispensation Migration
-- Replaces pure FIFO with Medical FEFO standard to ensure inventory safety
-- and prevent patient administration of near-expiry or expired pharmaceuticals/vaccines.
-- ============================================================================

-- 1. Upgrade Standard Dispensation Function to FEFO
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
  v_batches_dispensed text[] := ARRAY[]::text[];
BEGIN
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

  -- 3. FEFO Loop: prioritize earliest expiring batch first (expiry_date ASC, then received_date ASC)
  FOR v_batch IN
    SELECT * FROM public.inventory_batches
    WHERE item_id = v_item.id 
      AND quantity_remaining > 0 
      AND expiry_date >= CURRENT_DATE
    ORDER BY expiry_date ASC, received_date ASC
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

  -- 4. Update Invoice Total
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

-- 2. Upgrade Multi-Tenant Dispensation Function to FEFO
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
  v_new_total numeric(10,2);
BEGIN
  -- Verify item exists in clinic
  SELECT name, unit_cost INTO v_item_name, v_unit_cost
  FROM public.inventory_items
  WHERE id = p_item_id AND (clinic_id = p_clinic_id OR clinic_id IS NULL);

  IF v_item_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found in current clinic.');
  END IF;

  -- Select earliest expiring non-expired batch with available stock in current clinic (FEFO)
  SELECT id, batch_number
  INTO v_batch_id, v_batch_num
  FROM public.inventory_batches
  WHERE item_id = p_item_id 
    AND (clinic_id = p_clinic_id OR clinic_id IS NULL)
    AND quantity_remaining >= p_quantity
    AND expiry_date >= CURRENT_DATE
  ORDER BY expiry_date ASC, received_date ASC
  LIMIT 1
  FOR UPDATE;

  IF v_batch_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient unexpired stock in clinic for FEFO dispensation.');
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
  );

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
    'fefo_enforced', true
  );
END;
$$;
