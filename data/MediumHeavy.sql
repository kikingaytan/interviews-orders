-- Cambia a la base de IcePortal de DEV
-- USE <IcePortal_DEV>;
SET NOCOUNT ON;

;WITH
-- 1. Última fecha de snapshot disponible en DEV (sin tocar las fechas)
snap AS (
    SELECT hist_date   = (SELECT MAX(snapshot_date) FROM snapshot.memberhistory),
           lookup_date = (SELECT MAX(snapshot_date) FROM snapshot.memberlookup)
),
-- 2. Configuraciones de PowerSTEPP por subcliente (ajusta el nombre de la base IceClient de DEV)
cfg_sub AS (
    SELECT SubClientID, COUNT(*) AS configs
    FROM IceClient.dbo.PowerSTEPPConfig
    GROUP BY SubClientID
),
-- 3. Por location group: el subcliente con más configuraciones
cfg_group AS (
    SELECT scl.source_system_library AS lib, scl.location_group,
           MAX(ISNULL(c.configs, 0))  AS max_configs,
           COUNT(DISTINCT scl.sub_client_id) AS subclientes
    FROM snapshot.subclient_location_group scl
    LEFT JOIN cfg_sub c ON c.SubClientID = scl.sub_client_id
    GROUP BY scl.source_system_library, scl.location_group
),
-- 4. Miembros del snapshot más reciente que existen en memberlookup
miembros AS (
    SELECT h.lib, h.membno, h.grpnum, COUNT(*) AS filas_historial
    FROM snapshot.memberhistory h
    CROSS JOIN snap
    WHERE h.snapshot_date = snap.hist_date
      AND EXISTS (SELECT 1 FROM snapshot.memberlookup ml
                  WHERE ml.membno = h.membno AND ml.lib = h.lib
                    AND ml.snapshot_date = snap.lookup_date)
    GROUP BY h.lib, h.membno, h.grpnum
),
-- 5. Clasificación
clasificados AS (
    SELECT m.lib, m.membno, m.grpnum, m.filas_historial,
           ISNULL(g.max_configs, 0) AS max_configs,
           ISNULL(g.subclientes, 0) AS subclientes,
           categoria = CASE WHEN ISNULL(g.max_configs, 0) >= 50000 THEN 'HEAVY'
                            WHEN ISNULL(g.max_configs, 0) >= 1000  THEN 'MEDIUM'
                            WHEN ISNULL(g.max_configs, 0) >= 1     THEN 'LIGHT'
                            ELSE 'NOCONFIG' END
    FROM miembros m
    LEFT JOIN cfg_group g ON g.lib = m.lib AND g.location_group = m.grpnum
),
ranked AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY categoria
                                      ORDER BY max_configs DESC, filas_historial DESC)
    FROM clasificados
)
SELECT categoria, lib, membno, grpnum, filas_historial, max_configs, subclientes
FROM ranked
WHERE rn <= 5
ORDER BY CASE categoria WHEN 'HEAVY' THEN 1 WHEN 'MEDIUM' THEN 2
                        WHEN 'LIGHT' THEN 3 ELSE 4 END, rn;

-- Fechas del snapshot que se usaron
SELECT (SELECT MAX(snapshot_date) FROM snapshot.memberhistory) AS hist_date,
       (SELECT MAX(snapshot_date) FROM snapshot.memberlookup)  AS lookup_date;