-- Chanho FPO: add mandatory farmer passbook upload and optional UPI UTR
ALTER TABLE public.farmer
  ADD COLUMN IF NOT EXISTS bank_passbook_url text,
  ADD COLUMN IF NOT EXISTS utr_number text;

CREATE OR REPLACE FUNCTION public.register_farmer_auto(
    p_name text,
    p_father_name text,
    p_date_of_birth date,
    p_mobile text,
    p_gender text,
    p_village text,
    p_panchayat text,
    p_block text,
    p_district text,
    p_state text,
    p_crop text,
    p_land text,
    p_category text,
    p_address text,
    p_aadhar_number text,
    p_bank_name text,
    p_bank_branch text,
    p_account_number text,
    p_ifsc_code text,
    p_payment_mode text,
    p_photo_url text,
    p_signature_url text,
    p_aadhar_url text,
    p_form_url text,
    p_land_record_url text,
    p_bank_passbook_url text,
    p_utr_number text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_assignment record;
    v_admin record;
    v_coordinator record;
    v_farmer record;
BEGIN
    IF NULLIF(btrim(p_bank_passbook_url), '') IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'BANK_PASSBOOK_REQUIRED',
            'message', 'Bank passbook upload करना अनिवार्य है।'
        );
    END IF;

    IF upper(btrim(coalesce(p_payment_mode, ''))) = 'UPI'
       AND NULLIF(btrim(p_utr_number), '') IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'UTR_REQUIRED',
            'message', 'UPI payment के लिए UTR/Transaction Number अनिवार्य है।'
        );
    END IF;

    SELECT bc.coordinator_id, bc.auth_user_id, bc.name, bc.status
    INTO v_coordinator
    FROM public.block_coordinators bc
    WHERE bc.auth_user_id = auth.uid()
      AND lower(btrim(coalesce(bc.status,''))) = 'active'
    LIMIT 1;

    IF v_coordinator.coordinator_id IS NOT NULL THEN
        SELECT aa.admin_id, aa.panchayat, aa.village
        INTO v_assignment
        FROM public.admin_area_assignments aa
        WHERE lower(btrim(aa.panchayat)) = lower(btrim(p_panchayat))
          AND lower(btrim(aa.village)) = lower(btrim(p_village))
          AND lower(btrim(coalesce(aa.status,''))) = 'active'
          AND aa.block_coordinator_assigned_by = v_coordinator.coordinator_id
        LIMIT 1;
    ELSE
        SELECT aa.admin_id, aa.panchayat, aa.village
        INTO v_assignment
        FROM public.admin_area_assignments aa
        WHERE lower(btrim(aa.panchayat)) = lower(btrim(p_panchayat))
          AND lower(btrim(aa.village)) = lower(btrim(p_village))
          AND lower(btrim(coalesce(aa.status,''))) = 'active'
        LIMIT 1;
    END IF;

    IF v_assignment.admin_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AREA_NOT_ASSIGNED',
            'message', 'इस Panchayat और Village का Active Area assignment नहीं मिला।'
        );
    END IF;

    SELECT a.admin_id, a.name, a.status
    INTO v_admin
    FROM public.admins a
    WHERE a.admin_id = v_assignment.admin_id
      AND lower(btrim(coalesce(a.status,'Active'))) = 'active'
    LIMIT 1;

    IF v_admin.admin_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ADMIN_NOT_FOUND',
            'message', 'इस Area का assigned Admin Active नहीं है।'
        );
    END IF;

    IF auth.uid() IS NOT NULL
       AND v_coordinator.coordinator_id IS NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM public.admins a
            WHERE a.auth_user_id = auth.uid()
              AND a.admin_id = v_assignment.admin_id
              AND lower(btrim(coalesce(a.status,'Active'))) = 'active'
        ) THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'AREA_ACCESS_DENIED',
                'message', 'यह Village आपके Admin Area में assigned नहीं है।'
            );
        END IF;
    END IF;

    INSERT INTO public.farmer (
        name, father_name, date_of_birth, mobile, gender,
        village, panchayat, block, district, state,
        crop, land, category, address, status, aadhar_number,
        bank_name, bank_branch, account_number, ifsc_code, payment_mode,
        photo_url, signature_url, aadhar_url, form_url, land_record_url,
        bank_passbook_url, utr_number,
        admin_id, registered_at,
        block_coordinator_registered_by, block_coordinator_registered_at
    )
    VALUES (
        p_name, p_father_name, p_date_of_birth, p_mobile, p_gender,
        p_village, p_panchayat, p_block, p_district, p_state,
        p_crop, p_land, p_category, p_address, 'Pending Admin Verification',
        p_aadhar_number,
        p_bank_name, p_bank_branch, p_account_number, p_ifsc_code, p_payment_mode,
        p_photo_url, p_signature_url, p_aadhar_url, p_form_url, p_land_record_url,
        p_bank_passbook_url, NULLIF(btrim(p_utr_number), ''),
        v_assignment.admin_id, now(),
        CASE WHEN v_coordinator.coordinator_id IS NOT NULL
             THEN v_coordinator.coordinator_id ELSE NULL END,
        CASE WHEN v_coordinator.coordinator_id IS NOT NULL
             THEN now() ELSE NULL END
    )
    RETURNING * INTO v_farmer;

    RETURN jsonb_build_object(
        'success', true,
        'registration_no', v_farmer.registration_no,
        'status', v_farmer.status,
        'admin_id', v_farmer.admin_id,
        'admin_name', v_admin.name,
        'panchayat', v_farmer.panchayat,
        'village', v_farmer.village,
        'block_coordinator_registered_by', v_farmer.block_coordinator_registered_by
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'DATABASE_ERROR',
            'message', SQLERRM
        );
END;
$function$;
