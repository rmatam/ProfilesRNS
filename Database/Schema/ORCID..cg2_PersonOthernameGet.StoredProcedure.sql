SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [ORCID.].[cg2_PersonOthernameGet]
 
    @PersonOthernameID  INT 

AS
 
    SELECT TOP 100 PERCENT
        [ORCID.].[PersonOthername].[PersonOthernameID]
        , [ORCID.].[PersonOthername].[PersonID]
        , [ORCID.].[PersonOthername].[OtherName]
        , [ORCID.].[PersonOthername].[PersonMessageID]
    FROM
        [ORCID.].[PersonOthername]
    WHERE
        [ORCID.].[PersonOthername].[PersonOthernameID] = @PersonOthernameID




GO
