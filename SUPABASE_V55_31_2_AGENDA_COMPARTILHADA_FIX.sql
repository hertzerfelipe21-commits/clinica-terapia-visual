-- V55.31.2 — AGENDA COMPARTILHADA SECRETARIA <-> ANDERSON
-- Execute uma vez no Supabase SQL Editor.
-- Mantém RLS ativo; não usa service_role/secret key.
BEGIN;

-- A Secretaria pode ler a agenda compartilhada, mas alterações são feitas por RPC segura.
ALTER TABLE public.agenda_compartilhada ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS agenda_select_shared ON public.agenda_compartilhada;
CREATE POLICY agenda_select_shared
ON public.agenda_compartilhada
FOR SELECT TO authenticated
USING (public.current_app_role() IN ('admin','cv','tv','secretaria'));

DROP POLICY IF EXISTS agenda_insert_shared ON public.agenda_compartilhada;
CREATE POLICY agenda_insert_shared
ON public.agenda_compartilhada
FOR INSERT TO authenticated
WITH CHECK (public.current_app_role() IN ('admin','cv','tv'));

DROP POLICY IF EXISTS agenda_update_shared ON public.agenda_compartilhada;
CREATE POLICY agenda_update_shared
ON public.agenda_compartilhada
FOR UPDATE TO authenticated
USING (public.current_app_role() IN ('admin','cv','tv'))
WITH CHECK (public.current_app_role() IN ('admin','cv','tv'));

-- Secretaria edita a agenda por RPC. O RPC valida o papel e o conflito de horário.
CREATE OR REPLACE FUNCTION public.secretaria_atualizar_agendamento(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  r text := public.current_app_role();
  aid uuid := nullif(payload->>'agenda_id','')::uuid;
  rec public.agenda_compartilhada%ROWTYPE;
  d date;
  t time;
  dur integer;
  conflito boolean;
BEGIN
  IF r NOT IN ('secretaria','admin') THEN
    RAISE EXCEPTION 'Somente Secretaria/Admin podem alterar a agenda.';
  END IF;
  IF aid IS NULL THEN RAISE EXCEPTION 'AGENDA_ID_OBRIGATORIO'; END IF;

  SELECT * INTO rec FROM public.agenda_compartilhada WHERE id=aid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'AGENDAMENTO_NAO_ENCONTRADO'; END IF;

  d := COALESCE(NULLIF(payload->>'data','')::date, rec.data);
  t := COALESCE(NULLIF(payload->>'hora','')::time, rec.hora);
  dur := greatest(5,coalesce(nullif(payload->>'duracao_min','')::integer,rec.duracao_min));

  SELECT EXISTS(
    SELECT 1 FROM public.agenda_compartilhada a
    WHERE a.id<>aid
      AND a.data=d
      AND a.status NOT IN ('Cancelado','Faltou','Reagendado','NEGADO')
      AND t < a.hora + make_interval(mins=>greatest(1,a.duracao_min))
      AND t + make_interval(mins=>dur) > a.hora
  ) INTO conflito;

  IF conflito THEN RAISE EXCEPTION 'HORARIO_OCUPADO'; END IF;

  UPDATE public.agenda_compartilhada
  SET paciente_id=COALESCE(NULLIF(payload->>'paciente_id',''),rec.paciente_id),
      codigo=COALESCE(NULLIF(payload->>'codigo',''),rec.codigo),
      paciente_nome=COALESCE(NULLIF(payload->>'paciente_nome',''),rec.paciente_nome),
      data=d,
      hora=t,
      duracao_min=dur,
      tipo=COALESCE(NULLIF(payload->>'tipo',''),rec.tipo),
      sessao=COALESCE(NULLIF(payload->>'sessao','')::integer,rec.sessao),
      status=COALESCE(NULLIF(payload->>'status',''),rec.status),
      observacao=COALESCE(payload->>'observacao',rec.observacao),
      payload=rec.payload || payload,
      atualizado_em=now()
  WHERE id=aid;

  RETURN jsonb_build_object('ok',true,'agenda_id',aid,'atualizado_em',now());
END;
$$;

REVOKE ALL ON FUNCTION public.secretaria_atualizar_agendamento(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.secretaria_atualizar_agendamento(jsonb) TO authenticated;

-- Anderson/Admin também podem atualizar o mesmo registro via RPC quando necessário.
CREATE OR REPLACE FUNCTION public.anderson_atualizar_agendamento(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  r text := public.current_app_role();
  aid uuid := nullif(payload->>'agenda_id','')::uuid;
  rec public.agenda_compartilhada%ROWTYPE;
BEGIN
  IF r NOT IN ('admin','cv','tv') THEN RAISE EXCEPTION 'Somente Anderson/Admin podem atualizar a agenda.'; END IF;
  IF aid IS NULL THEN RAISE EXCEPTION 'AGENDA_ID_OBRIGATORIO'; END IF;
  SELECT * INTO rec FROM public.agenda_compartilhada WHERE id=aid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'AGENDAMENTO_NAO_ENCONTRADO'; END IF;
  UPDATE public.agenda_compartilhada
  SET status=COALESCE(NULLIF(payload->>'status',''),rec.status),
      observacao=COALESCE(payload->>'observacao',rec.observacao),
      payload=rec.payload || payload,
      atualizado_em=now()
  WHERE id=aid;
  RETURN jsonb_build_object('ok',true,'agenda_id',aid,'atualizado_em',now());
END;
$$;
REVOKE ALL ON FUNCTION public.anderson_atualizar_agendamento(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.anderson_atualizar_agendamento(jsonb) TO authenticated;

NOTIFY pgrst,'reload schema';
COMMIT;
