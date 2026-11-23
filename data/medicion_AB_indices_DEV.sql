/******************************************************************************
 Medicion A/B en DEV de los indices nuevos - SIN permisos de ALTER
 Solo lectura: no cambia nada en la base.

 A = "ANTES": hints que fuerzan los indices viejos
 B = "DESPUES": sin hints, el optimizador puede usar los indices nuevos

 Como usarlo:
  1. Paso 0: saca los parametros de un miembro (uno NOCONFIG, uno HEAVY, uno MEDIUM).
  2. Copia esos valores en los DECLARE del paso 1.
  3. Corre A y B dos veces cada uno; usa la 2a corrida (cache caliente).
  4. En la pestana Messages compara "logical reads" por tabla y el
     "CPU time / elapsed time" de cada consulta.
 Activa el plan real (Ctrl+M) para ver que indice usa cada una.
******************************************************************************/

/*--- Paso 0: parametros de un miembro (mismo calculo que tu harness) ---*/
/*
SELECT H.membno, H.lib, H.grpnum, H.benpkg, H.benrds, H.tiercd, H.priprvorg, H.secprvorg,
       eff = CASE WHEN H.effdat < '2010-01-01' AND H.expdat > '2010-01-01'
                  THEN CAST('2010-01-01' AS date) ELSE H.effdat END
FROM IcePortal.memberhistory H
WHERE H.lib = 'NLB'
  AND H.membno = '...';   -- membno de prueba
*/

USE [IceClient];
GO
SET NOCOUNT ON;
SET STATISTICS IO, TIME ON;

/*--- Paso 1: parametros ---*/
DECLARE @Library         CHAR(3)     = 'NLB',
        @GRPNUM          VARCHAR(6)  = '......',
        @BENPKG          VARCHAR(4)  = '....',
        @PrimaryPRVORG   VARCHAR(4)  = '....',
        @SecondaryPRVORG VARCHAR(4)  = '',
        @EffectiveDate   DATE        = '2021-01-01';

PRINT '================ A) ANTES (indices viejos forzados) ================';
SELECT COUNT(*) AS configs_A
FROM dbo.PowerSTEPPConfig pc WITH (NOLOCK, INDEX(SubClientID_IX))
INNER JOIN dbo.SubClient s WITH (NOLOCK)
    ON pc.SubClientID = s.ID
   AND @EffectiveDate BETWEEN s.EffectiveDate AND s.ExpirationDate
   AND s.EffectiveDate <> s.ExpirationDate
INNER JOIN dbo.SubClientLocationGroupXWalk x WITH (NOLOCK, INDEX(LocationGroupXWalkID_IX))
    ON s.ID = x.SubClientID
   AND @EffectiveDate BETWEEN x.EffectiveDate AND x.ExpirationDate
   AND x.EffectiveDate <> x.ExpirationDate
INNER JOIN dbo.LocationGroupXWalk l WITH (NOLOCK)
    ON x.LocationGroupXWalkID = l.ID
   AND @EffectiveDate BETWEEN l.EffectiveDate AND l.ExpirationDate
   AND l.EffectiveDate <> l.ExpirationDate
INNER JOIN dbo.Client cl WITH (NOLOCK)
    ON l.ClientID = cl.ID
   AND @EffectiveDate BETWEEN cl.EffectiveDate AND cl.ExpirationDate
   AND cl.EffectiveDate <> cl.ExpirationDate
INNER JOIN dbo.SourceSystem ss WITH (NOLOCK)
    ON cl.ICESourceSystemID = ss.ID
INNER JOIN dbo.Benefit b WITH (NOLOCK, INDEX(Benefit_PK))
    ON pc.BenefitID = b.ID
   AND @EffectiveDate BETWEEN b.EffectiveDate AND b.ExpirationDate
   AND b.EffectiveDate <> b.ExpirationDate
INNER JOIN dbo.BenefitPackage bp WITH (NOLOCK)
    ON b.BenefitPackageID = bp.ID
   AND @EffectiveDate BETWEEN bp.EffectiveDate AND bp.ExpirationDate
   AND bp.EffectiveDate <> bp.ExpirationDate
LEFT OUTER JOIN dbo.ProviderNetwork n WITH (NOLOCK)
    ON pc.ProviderNetworkID = n.ID
   AND @EffectiveDate BETWEEN n.EffectiveDate AND n.ExpirationDate
   AND n.EffectiveDate <> n.ExpirationDate
LEFT OUTER JOIN dbo.Rider pr WITH (NOLOCK)
    ON n.PrimaryRiderID = pr.ID
   AND @EffectiveDate BETWEEN pr.EffectiveDate AND pr.ExpirationDate
   AND pr.EffectiveDate <> pr.ExpirationDate
LEFT OUTER JOIN dbo.Rider sr WITH (NOLOCK)
    ON n.SecondaryRiderID = sr.ID
   AND @EffectiveDate BETWEEN sr.EffectiveDate AND sr.ExpirationDate
   AND sr.EffectiveDate <> sr.ExpirationDate
WHERE ss.Library = @Library
  AND l.ICEHierarchyLevel3 = @GRPNUM
  AND bp.BENPKG = @BENPKG
  AND ISNULL(n.PrimaryPRVORG, '')   = ISNULL(@PrimaryPRVORG, '')
  AND ISNULL(n.SecondaryPRVORG, '') = ISNULL(@SecondaryPRVORG, '')
  AND @EffectiveDate BETWEEN pc.EffectiveDate AND pc.ExpirationDate
  AND pc.EffectiveDate <> pc.ExpirationDate;

PRINT '================ B) DESPUES (sin hints) ================';
SELECT COUNT(*) AS configs_B
FROM dbo.PowerSTEPPConfig pc WITH (NOLOCK)
INNER JOIN dbo.SubClient s WITH (NOLOCK)
    ON pc.SubClientID = s.ID
   AND @EffectiveDate BETWEEN s.EffectiveDate AND s.ExpirationDate
   AND s.EffectiveDate <> s.ExpirationDate
INNER JOIN dbo.SubClientLocationGroupXWalk x WITH (NOLOCK)
    ON s.ID = x.SubClientID
   AND @EffectiveDate BETWEEN x.EffectiveDate AND x.ExpirationDate
   AND x.EffectiveDate <> x.ExpirationDate
INNER JOIN dbo.LocationGroupXWalk l WITH (NOLOCK)
    ON x.LocationGroupXWalkID = l.ID
   AND @EffectiveDate BETWEEN l.EffectiveDate AND l.ExpirationDate
   AND l.EffectiveDate <> l.ExpirationDate
INNER JOIN dbo.Client cl WITH (NOLOCK)
    ON l.ClientID = cl.ID
   AND @EffectiveDate BETWEEN cl.EffectiveDate AND cl.ExpirationDate
   AND cl.EffectiveDate <> cl.ExpirationDate
INNER JOIN dbo.SourceSystem ss WITH (NOLOCK)
    ON cl.ICESourceSystemID = ss.ID
INNER JOIN dbo.Benefit b WITH (NOLOCK)
    ON pc.BenefitID = b.ID
   AND @EffectiveDate BETWEEN b.EffectiveDate AND b.ExpirationDate
   AND b.EffectiveDate <> b.ExpirationDate
INNER JOIN dbo.BenefitPackage bp WITH (NOLOCK)
    ON b.BenefitPackageID = bp.ID
   AND @EffectiveDate BETWEEN bp.EffectiveDate AND bp.ExpirationDate
   AND bp.EffectiveDate <> bp.ExpirationDate
LEFT OUTER JOIN dbo.ProviderNetwork n WITH (NOLOCK)
    ON pc.ProviderNetworkID = n.ID
   AND @EffectiveDate BETWEEN n.EffectiveDate AND n.ExpirationDate
   AND n.EffectiveDate <> n.ExpirationDate
LEFT OUTER JOIN dbo.Rider pr WITH (NOLOCK)
    ON n.PrimaryRiderID = pr.ID
   AND @EffectiveDate BETWEEN pr.EffectiveDate AND pr.ExpirationDate
   AND pr.EffectiveDate <> pr.ExpirationDate
LEFT OUTER JOIN dbo.Rider sr WITH (NOLOCK)
    ON n.SecondaryRiderID = sr.ID
   AND @EffectiveDate BETWEEN sr.EffectiveDate AND sr.ExpirationDate
   AND sr.EffectiveDate <> sr.ExpirationDate
WHERE ss.Library = @Library
  AND l.ICEHierarchyLevel3 = @GRPNUM
  AND bp.BENPKG = @BENPKG
  AND ISNULL(n.PrimaryPRVORG, '')   = ISNULL(@PrimaryPRVORG, '')
  AND ISNULL(n.SecondaryPRVORG, '') = ISNULL(@SecondaryPRVORG, '')
  AND @EffectiveDate BETWEEN pc.EffectiveDate AND pc.ExpirationDate
  AND pc.EffectiveDate <> pc.ExpirationDate;

SET STATISTICS IO, TIME OFF;
-- configs_A y configs_B deben dar el mismo numero (mismo resultado, distinto camino)
