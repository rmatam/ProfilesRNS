SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [ORCID.].[cg2_OrganizationDepartmentsGet]
 
AS
 
    SELECT TOP 100 PERCENT
        [Profile.Data].[Organization.Department].[DepartmentID]
        , [Profile.Data].[Organization.Department].[DepartmentName]
        , [Profile.Data].[Organization.Department].[Visible]
    FROM
        [Profile.Data].[Organization.Department]


GO
