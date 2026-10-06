-- V55.31.2 — sincronização clínica centralizada e bidirecional
-- Mantém RLS ativo. Não usa service_role no navegador e não usa WITH CHECK (true).
-- Executar no SQL Editor do projeto Supabase com uma role que possa criar tabela/funções.

BEGIN;

CREATE TABLE IF NOT EXISTS public.clinical_sync_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  revision bigint NOT NULL DEFAULT 0,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_by_device text NOT NULL,
  client_updated_at timestamptz,
  server_updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.clinical_sync_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS clinical_sync_select_own ON public.clinical_sync_state;
CREATE POLICY clinical_sync_select_own
ON public.clinical_sync_state
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  AND public.current_app_role() IN ('admin','cv','tv')
);

-- O cliente não recebe INSERT/UPDATE/DELETE direto. Tudo passa pelos RPCs abaixo.
REVOKE ALL ON TABLE public.clinical_sync_state FROM anon, authenticated;
GRANT SELECT ON TABLE public.clinical_sync_state TO authenticated;

CREATE OR REPLACE FUNCTION public.push_clinical_snapshot(
  p_device_id text,
  p_base_revision bigint,
  p_force boolean,
  p_payload jsonb,
  p_client_updated_at timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_role text := public.current_app_role();
  v_current public.clinical_sync_state%ROWTYPE;
  v_new_revision bigint;
BEGIN
  IF v_uid IS NULL OR v_role NOT IN ('admin','cv','tv') THEN
    RAISE EXCEPTION 'Acesso não autorizado para sincronização clínica';
  END IF;
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RAISE EXCEPTION 'Snapshot clínico inválido';
  END IF;
  IF coalesce(length(trim(p_device_id)),0) = 0 OR length(p_device_id) > 160 THEN
    RAISE EXCEPTION 'Identificador do dispositivo inválido';
  END IF;

  SELECT * INTO v_current
  FROM public.clinical_sync_state
  WHERE user_id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.clinical_sync_state
      (user_id, revision, payload, updated_by_device, client_updated_at, server_updated_at)
    VALUES
      (v_uid, 1, p_payload, p_device_id, p_client_updated_at, now());
    RETURN jsonb_build_object('ok',true,'found',true,'revision',1,'conflict',false);
  END IF;

  IF NOT p_force AND coalesce(p_base_revision,0) <> v_current.revision THEN
    RETURN jsonb_build_object(
      'ok',false,
      'found',true,
      'conflict',true,
      'current_revision',v_current.revision,
      'current_updated_by_device',v_current.updated_by_device,
      'current_server_updated_at',v_current.server_updated_at,
      'payload',v_current.payload
    );
  END IF;

  v_new_revision := v_current.revision + 1;
  UPDATE public.clinical_sync_state
     SET revision = v_new_revision,
         payload = p_payload,
         updated_by_device = p_device_id,
         client_updated_at = p_client_updated_at,
         server_updated_at = now()
   WHERE user_id = v_uid;

  RETURN jsonb_build_object('ok',true,'found',true,'revision',v_new_revision,'conflict',false);
END;
$$;

CREATE OR REPLACE FUNCTION public.pull_clinical_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_role text := public.current_app_role();
  v_current public.clinical_sync_state%ROWTYPE;
BEGIN
  IF v_uid IS NULL OR v_role NOT IN ('admin','cv','tv') THEN
    RAISE EXCEPTION 'Acesso não autorizado para sincronização clínica';
  END IF;

  SELECT * INTO v_current
  FROM public.clinical_sync_state
  WHERE user_id = v_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found',false);
  END IF;

  RETURN jsonb_build_object(
    'found',true,
    'revision',v_current.revision,
    'payload',v_current.payload,
    'updated_by_device',v_current.updated_by_device,
    'client_updated_at',v_current.client_updated_at,
    'server_updated_at',v_current.server_updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.push_clinical_snapshot(text,bigint,boolean,jsonb,timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pull_clinical_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.push_clinical_snapshot(text,bigint,boolean,jsonb,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pull_clinical_snapshot() TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
