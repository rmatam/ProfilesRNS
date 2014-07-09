SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ORCID.].[cg2_OrganizationInstitutionsGet]
 
AS
 
    SELECT TOP 100 PERCENT
        [Profile.Data].[Organization.Institution].[InstitutionID]
        , [Profile.Data].[Organization.Institution].[InstitutionName]
        , [Profile.Data].[Organization.Institution].[InstitutionAbbreviation]
    FROM
        [Profile.Data].[Organization.Institution]


GO
