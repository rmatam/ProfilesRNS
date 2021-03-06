SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 
CREATE PROCEDURE [ORCID.].[cg2_FieldLevelAuditTrailAdd]

    @FieldLevelAuditTrailID  BIGINT =NULL OUTPUT 
    , @RecordLevelAuditTrailID  BIGINT 
    , @MetaFieldID  INT 
    , @ValueBefore  VARCHAR(50) =NULL
    , @ValueAfter  VARCHAR(50) =NULL

AS


    DECLARE @intReturnVal INT 
    SET @intReturnVal = 0
    DECLARE @strReturn  Varchar(200) 
    SET @intReturnVal = 0
 
  
        INSERT INTO [ORCID.].[FieldLevelAuditTrail]
        (
            [RecordLevelAuditTrailID]
            , [MetaFieldID]
            , [ValueBefore]
            , [ValueAfter]
        )
        (
            SELECT
            @RecordLevelAuditTrailID
            , @MetaFieldID
            , @ValueBefore
            , @ValueAfter
        )
   
        SET @intReturnVal = @@error
        SET @FieldLevelAuditTrailID = @@IDENTITY
        IF @intReturnVal <> 0
        BEGIN
            RAISERROR (N'An error occurred while adding the FieldLevelAuditTrail record.', 11, 11); 
            RETURN @intReturnVal 
        END



GO
