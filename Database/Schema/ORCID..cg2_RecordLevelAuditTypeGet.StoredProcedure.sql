SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [ORCID.].[cg2_RecordLevelAuditTypeGet]
 
    @RecordLevelAuditTypeID  INT 

AS
 
    SELECT TOP 100 PERCENT
        [ORCID.].[RecordLevelAuditType].[RecordLevelAuditTypeID]
        , [ORCID.].[RecordLevelAuditType].[AuditType]
    FROM
        [ORCID.].[RecordLevelAuditType]
    WHERE
        [ORCID.].[RecordLevelAuditType].[RecordLevelAuditTypeID] = @RecordLevelAuditTypeID




GO
