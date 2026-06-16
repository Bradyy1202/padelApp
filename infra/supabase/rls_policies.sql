-- Políticas RLS — específicas de Supabase (PRD §10.9).
-- Aplicar SOLO en proyectos Supabase (usa auth.uid() y los roles anon/authenticated/service_role).
-- NO forma parte de las migraciones Prisma que corren contra el Postgres local de docker.
--
-- Frontera de seguridad (PRD §9.2): las tablas de partidos/rating/pozos/torneos son SOLO LECTURA
-- para el cliente; su escritura está restringida al service_role que usa NestJS.
-- Nota: service_role omite RLS automáticamente en Supabase, por eso no se crean políticas de
-- INSERT/UPDATE para usuarios normales en esas tablas (quedan denegadas por defecto).

-- ───────────── Lectura pública (datos no sensibles) ─────────────
ALTER TABLE "profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "players"  ENABLE ROW LEVEL SECURITY;
ALTER TABLE "clubs"    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_public" ON "profiles"
  FOR SELECT USING (true);

CREATE POLICY "players_select_public" ON "players"
  FOR SELECT USING (true);

CREATE POLICY "clubs_select_public" ON "clubs"
  FOR SELECT USING (true);

-- El dueño puede actualizar su propio player (UPDATE solo del propietario, §10.9).
CREATE POLICY "players_update_owner" ON "players"
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ───────────── Tablas de negocio: SELECT permitido, escritura solo service_role ─────────────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'matches','match_teams','match_players','match_sets','match_results',
    'match_confirmations','qr_tokens','rating_current','rating_history',
    'pozos','pozo_participants','pozo_rounds','pozo_matches','pozo_standings',
    'tournaments','tournament_categories','tournament_registrations','tournament_matches',
    'notifications','devices','reports'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR SELECT TO authenticated USING (true);',
      t || '_select_auth', t
    );
  END LOOP;
END $$;

-- ───────────── audit_log: solo service_role (sin políticas => denegado a clientes) ─────────────
ALTER TABLE "audit_log" ENABLE ROW LEVEL SECURITY;

-- ───────────── Lectura del ranking materializado ─────────────
-- Las vistas materializadas no soportan RLS por fila; se exponen vía RPC/Postgrest con grants.
GRANT SELECT ON "mv_rankings" TO anon, authenticated;
