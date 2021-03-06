SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [ORCID.].[AffiliationsForORCID.GetList]
	@ProfileDataPersonID bigint = NULL
AS
BEGIN
SELECT        TOP (100) PERCENT NULL AS PersonAffiliationID, [Profile.Data].[Person.Affiliation].PersonAffiliationID AS ProfilesID, 2 AS AffiliationTypeID, 
                         NULL AS PersonID, NULL AS PersonMessageID, NULL AS DecisionID, [Profile.Data].[Organization.Department].DepartmentName, 
                         [Profile.Data].[Person.Affiliation].Title AS RoleTitle, NULL AS StartDate, NULL AS EndDate, 
                         [Profile.Data].[Organization.Institution].InstitutionName AS OrganizationName, [Profile.Data].Person.City, 
                         [Profile.Data].Person.State, 'US' as Country, [ORCID.].[Organization.Institution.Disambiguation].DisambiguationID, 
                         [ORCID.].[Organization.Institution.Disambiguation].DisambiguationSource, [Profile.Data].[Person.Affiliation].SortOrder
FROM            [Profile.Data].Person INNER JOIN
                         [Profile.Data].[Person.Affiliation] ON [Profile.Data].Person.PersonID = [Profile.Data].[Person.Affiliation].PersonID INNER JOIN
                         [Profile.Data].[Organization.Institution] ON [Profile.Data].[Person.Affiliation].InstitutionID = [Profile.Data].[Organization.Institution].InstitutionID LEFT OUTER JOIN
                         [Profile.Data].[Organization.Division] ON [Profile.Data].[Person.Affiliation].DivisionID = [Profile.Data].[Organization.Division].DivisionID LEFT OUTER JOIN
                         [Profile.Data].[Organization.Department] ON [Profile.Data].[Person.Affiliation].DepartmentID = [Profile.Data].[Organization.Department].DepartmentID LEFT OUTER JOIN
						 [ORCID.].[Organization.Institution.Disambiguation] ON [Profile.Data].[Person.Affiliation].InstitutionID = [ORCID.].[Organization.Institution.Disambiguation].InstitutionID

WHERE        ([Profile.Data].Person.PersonID = @ProfileDataPersonID)
ORDER BY [Profile.Data].[Person.Affiliation].SortOrder
End

GO
