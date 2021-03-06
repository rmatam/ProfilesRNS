/*
Run this script on:

        Profiles 2.8.0   -  This database will be modified

to synchronize it with:

        Profiles 2.9.0

You are recommended to back up your database before running this script

Details of which objects have changed can be found in the release notes.
If you have made changes to existing tables or stored procedures in profiles, you may need to merge changes individually. 

*/


/***
* 
* Modifications required to handle Semantic type xml as a seperate file
*
***/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [Profile.Data].[Concept.Mesh.SemanticType.XML](
	[DescriptorUI] [varchar](10) NOT NULL,
	[x] [xml] NULL,
PRIMARY KEY CLUSTERED 
(
	[DescriptorUI] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Profile.Data].[Concept.Mesh.ParseMeshXML]
AS
BEGIN
	SET NOCOUNT ON;

	-- Clear any existing data
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.XML]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.Descriptor]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.Qualifier]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.Term]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.SemanticType]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.SemanticGroupType]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.SemanticGroup]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.Tree]
	TRUNCATE TABLE [Profile.Data].[Concept.Mesh.TreeTop]

	-- Extract items from SemGroups.xml
	INSERT INTO [Profile.Data].[Concept.Mesh.SemanticGroupType] (SemanticGroupUI,SemanticGroupName,SemanticTypeUI,SemanticTypeName)
		SELECT 
			S.x.value('SemanticGroupUI[1]','varchar(10)'),
			S.x.value('SemanticGroupName[1]','varchar(50)'),
			S.x.value('SemanticTypeUI[1]','varchar(10)'),
			S.x.value('SemanticTypeName[1]','varchar(50)')
		FROM [Profile.Data].[Concept.Mesh.File] CROSS APPLY Data.nodes('//SemanticType') AS S(x)
		WHERE Name = 'SemGroups.xml'

	-- Extract items from SemTypes.xml
	INSERT INTO [Profile.Data].[Concept.Mesh.SemanticType.XML] (DescriptorUI, x)
		SELECT
				D.x.value('DescriptorUI[1]','varchar(100)'),
				D.x.query('SemanticTypeList[1]') SemanticTypeName
			FROM [Profile.Data].[Concept.Mesh.File] m 
				CROSS APPLY Data.nodes('//DescriptorRecord') AS D(x)
				WHERE Name = 'SemTypes.xml'

	INSERT INTO [Profile.Data].[Concept.Mesh.SemanticType] (DescriptorUI, SemanticTypeUI, SemanticTypeName)
		SELECT
				DescriptorUI,
				D.x.value('SemanticTypeUI[1]','varchar(10)') SemanticTypeUI,
				D.x.value('SemanticTypeName[1]','varchar(50)') SemanticTypeName
			FROM [Profile.Data].[Concept.Mesh.SemanticType.XML] m 
				CROSS APPLY X.nodes('//SemanticType') AS D(x)
		
	INSERT INTO [Profile.Data].[Concept.Mesh.SemanticGroup] (DescriptorUI, SemanticGroupUI, SemanticGroupName)
		SELECT DISTINCT t.DescriptorUI, g.SemanticGroupUI, g.SemanticGroupName
			FROM [Profile.Data].[Concept.Mesh.SemanticGroupType] g, [Profile.Data].[Concept.Mesh.SemanticType] t
			WHERE g.SemanticTypeUI = t.SemanticTypeUI

		-- Extract items from MeSH2011.xml
	INSERT INTO [Profile.Data].[Concept.Mesh.XML] (DescriptorUI, MeSH)
		SELECT D.x.value('DescriptorUI[1]','varchar(10)'), D.x.query('.')
			FROM [Profile.Data].[Concept.Mesh.File] CROSS APPLY Data.nodes('//DescriptorRecord') AS D(x)
			WHERE Name = 'MeSH.xml'


	---------------------------------------
	-- Parse MeSH XML and populate tables
	---------------------------------------


	INSERT INTO [Profile.Data].[Concept.Mesh.Descriptor] (DescriptorUI, DescriptorName)
		SELECT DescriptorUI, MeSH.value('DescriptorRecord[1]/DescriptorName[1]/String[1]','varchar(255)')
			FROM [Profile.Data].[Concept.Mesh.XML]

	INSERT INTO [Profile.Data].[Concept.Mesh.Qualifier] (DescriptorUI, QualifierUI, DescriptorName, QualifierName, Abbreviation)
		SELECT	m.DescriptorUI,
				Q.x.value('QualifierReferredTo[1]/QualifierUI[1]','varchar(10)'),
				m.MeSH.value('DescriptorRecord[1]/DescriptorName[1]/String[1]','varchar(255)'),
				Q.x.value('QualifierReferredTo[1]/QualifierName[1]/String[1]','varchar(255)'),
				Q.x.value('Abbreviation[1]','varchar(2)')
			FROM [Profile.Data].[Concept.Mesh.XML] m CROSS APPLY MeSH.nodes('//AllowableQualifier') AS Q(x)

	SELECT	m.DescriptorUI,
			C.x.value('ConceptUI[1]','varchar(10)') ConceptUI,
			m.MeSH.value('DescriptorRecord[1]/DescriptorName[1]/String[1]','varchar(255)') DescriptorName,
			C.x.value('@PreferredConceptYN[1]','varchar(1)') PreferredConceptYN,
			C.x.value('ConceptRelationList[1]/ConceptRelation[1]/@RelationName[1]','varchar(3)') RelationName,
			C.x.value('ConceptName[1]/String[1]','varchar(255)') ConceptName,
			C.x.query('.') ConceptXML
		INTO #c
		FROM [Profile.Data].[Concept.Mesh.XML] m 
			CROSS APPLY MeSH.nodes('//Concept') AS C(x)

	INSERT INTO [Profile.Data].[Concept.Mesh.Term] (DescriptorUI, ConceptUI, TermUI, TermName, DescriptorName, PreferredConceptYN, RelationName, ConceptName, ConceptPreferredTermYN, IsPermutedTermYN, LexicalTag)
		SELECT	DescriptorUI,
				ConceptUI,
				T.x.value('TermUI[1]','varchar(10)'),
				T.x.value('String[1]','varchar(255)'),
				DescriptorName,
				PreferredConceptYN,
				RelationName,
				ConceptName,
				T.x.value('@ConceptPreferredTermYN[1]','varchar(1)'),
				T.x.value('@IsPermutedTermYN[1]','varchar(1)'),
				T.x.value('@LexicalTag[1]','varchar(3)')
			FROM #c C CROSS APPLY ConceptXML.nodes('//Term') AS T(x)

	INSERT INTO [Profile.Data].[Concept.Mesh.Tree] (DescriptorUI, TreeNumber)
		SELECT	m.DescriptorUI,
				T.x.value('.','varchar(255)')
			FROM [Profile.Data].[Concept.Mesh.XML] m 
				CROSS APPLY MeSH.nodes('//TreeNumber') AS T(x)

	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] (TreeNumber, DescriptorName)
		SELECT	T.x.value('.','varchar(255)'),
				m.MeSH.value('DescriptorRecord[1]/DescriptorName[1]/String[1]','varchar(255)')
			FROM [Profile.Data].[Concept.Mesh.XML] m 
				CROSS APPLY MeSH.nodes('//TreeNumber') AS T(x)
	UPDATE [Profile.Data].[Concept.Mesh.TreeTop]
		SET TreeNumber = left(TreeNumber,1)+'.'+TreeNumber
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('A','Anatomy')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('B','Organisms')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('C','Diseases')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('D','Chemicals and Drugs')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('E','Analytical, Diagnostic and Therapeutic Techniques and Equipment')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('F','Psychiatry and Psychology')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('G','Biological Sciences')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('H','Natural Sciences')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('I','Anthropology, Education, Sociology and Social Phenomena')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('J','Technology, Industry, Agriculture')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('K','Humanities')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('L','Information Science')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('M','Named Groups')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('N','Health Care')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('V','Publication Characteristics')
	INSERT INTO [Profile.Data].[Concept.Mesh.TreeTop] VALUES ('Z','Geographicals')

END
GO


/***
* 
* Fix for edits to publication dates in custom publications not saved
*
***/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Profile.Data].[Publication.Entity.UpdateEntity]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

 
	-- *******************************************************************
	-- *******************************************************************
	-- Update InformationResource entities
	-- *******************************************************************
	-- *******************************************************************
 
 
	----------------------------------------------------------------------
	-- Get a list of current publications
	----------------------------------------------------------------------

	CREATE TABLE #Publications
	(
		PMID INT NULL ,
		MPID NVARCHAR(50) NULL ,
		PMCID NVARCHAR(55) NULL,
		EntityDate DATETIME NULL ,
		Reference VARCHAR(MAX) NULL ,
		Source VARCHAR(25) NULL ,
		URL VARCHAR(1000) NULL ,
		Title VARCHAR(4000) NULL ,
		EntityID INT NULL
	)
 
	-- Add PMIDs to the publications temp table
	INSERT  INTO #Publications
            ( PMID ,
			  PMCID,
              EntityDate ,
              Reference ,
              Source ,
              URL ,
              Title
            )
            SELECT -- Get Pub Med pubs
                    PG.PMID ,
					PG.PMCID,
                    EntityDate = PG.PubDate,
                    Reference = REPLACE([Profile.Cache].[fnPublication.Pubmed.General2Reference](PG.PMID,
                                                              PG.ArticleDay,
                                                              PG.ArticleMonth,
                                                              PG.ArticleYear,
                                                              PG.ArticleTitle,
                                                              PG.Authors,
                                                              PG.AuthorListCompleteYN,
                                                              PG.Issue,
                                                              PG.JournalDay,
                                                              PG.JournalMonth,
                                                              PG.JournalYear,
                                                              PG.MedlineDate,
                                                              PG.MedlinePgn,
                                                              PG.MedlineTA,
                                                              PG.Volume, 0),
                                        CHAR(11), '') ,
                    Source = 'PubMed',
                    URL = 'http://www.ncbi.nlm.nih.gov/pubmed/' + CAST(ISNULL(PG.pmid, '') AS VARCHAR(20)),
                    Title = left((case when IsNull(PG.ArticleTitle,'') <> '' then PG.ArticleTitle else 'Untitled Publication' end),4000)
            FROM    [Profile.Data].[Publication.PubMed.General] PG
			WHERE	PG.PMID IN (
						SELECT PMID 
						FROM [Profile.Data].[Publication.Person.Include]
						WHERE PMID IS NOT NULL )
 
	-- Add MPIDs to the publications temp table
	INSERT  INTO #Publications
            ( MPID ,
              EntityDate ,
			  Reference ,
			  Source ,
              URL ,
              Title
            )
            SELECT  MPID ,
                    EntityDate ,
                    Reference = REPLACE(authors
										+ (CASE WHEN IsNull(article,'') <> '' THEN article + '. ' ELSE '' END)
										+ (CASE WHEN IsNull(pub,'') <> '' THEN pub + '. ' ELSE '' END)
										+ y
                                        + CASE WHEN y <> ''
                                                    AND vip <> '' THEN '; '
                                               ELSE ''
                                          END + vip
                                        + CASE WHEN y <> ''
                                                    OR vip <> '' THEN '.'
                                               ELSE ''
                                          END, CHAR(11), '') ,
                    Source = 'Custom' ,
                    URL = url,
                    Title = left((case when IsNull(article,'')<>'' then article when IsNull(pub,'')<>'' then pub else 'Untitled Publication' end),4000)
            FROM    ( SELECT    MPID ,
                                EntityDate ,
                                url ,
                                authors = CASE WHEN authors = '' THEN ''
                                               WHEN RIGHT(authors, 1) = '.'
                                               THEN LEFT(authors,
                                                         LEN(authors) - 1)
                                               ELSE authors
                                          END ,
                                article = CASE WHEN article = '' THEN ''
                                               WHEN RIGHT(article, 1) = '.'
                                               THEN LEFT(article,
                                                         LEN(article) - 1)
                                               ELSE article
                                          END ,
                                pub = CASE WHEN pub = '' THEN ''
                                           WHEN RIGHT(pub, 1) = '.'
                                           THEN LEFT(pub, LEN(pub) - 1)
                                           ELSE pub
                                      END ,
                                y ,
                                vip
                      FROM      ( SELECT    MPG.mpid ,
                                            EntityDate = MPG.publicationdt ,
                                            authors = CASE WHEN RTRIM(LTRIM(COALESCE(MPG.authors,
                                                              ''))) = ''
                                                           THEN ''
                                                           WHEN RIGHT(COALESCE(MPG.authors,
                                                              ''), 1) = '.'
                                                            THEN  COALESCE(MPG.authors,
                                                              '') + ' '
                                                           ELSE COALESCE(MPG.authors,
                                                              '') + '. '
                                                      END ,
                                            url = CASE WHEN COALESCE(MPG.url,
                                                              '') <> ''
                                                            AND LEFT(COALESCE(MPG.url,
                                                              ''), 4) = 'http'
                                                       THEN MPG.url
                                                       WHEN COALESCE(MPG.url,
                                                              '') <> ''
                                                       THEN 'http://' + MPG.url
                                                       ELSE ''
                                                  END ,
                                            article = LTRIM(RTRIM(COALESCE(MPG.articletitle,
                                                              ''))) ,
                                            pub = LTRIM(RTRIM(COALESCE(MPG.pubtitle,
                                                              ''))) ,
                                            y = CASE WHEN MPG.publicationdt > '1/1/1901'
                                                     THEN CONVERT(VARCHAR(50), YEAR(MPG.publicationdt))
                                                     ELSE ''
                                                END ,
                                            vip = COALESCE(MPG.volnum, '')
                                            + CASE WHEN COALESCE(MPG.issuepub,
                                                              '') <> ''
                                                   THEN '(' + MPG.issuepub
                                                        + ')'
                                                   ELSE ''
                                              END
                                            + CASE WHEN ( COALESCE(MPG.paginationpub,
                                                              '') <> '' )
                                                        AND ( COALESCE(MPG.volnum,
                                                              '')
                                                              + COALESCE(MPG.issuepub,
                                                              '') <> '' )
                                                   THEN ':'
                                                   ELSE ''
                                              END + COALESCE(MPG.paginationpub,
                                                             '')
                                  FROM      [Profile.Data].[Publication.MyPub.General] MPG
                                  INNER JOIN [Profile.Data].[Publication.Person.Include] PL ON MPG.mpid = PL.mpid
                                                           AND PL.mpid NOT LIKE 'DASH%'
                                                           AND PL.mpid NOT LIKE 'ISI%'
                                                           AND PL.pmid IS NULL
                                ) T0
                    ) T0
 
	CREATE NONCLUSTERED INDEX idx_pmid on #publications(pmid)
	CREATE NONCLUSTERED INDEX idx_mpid on #publications(mpid)

	----------------------------------------------------------------------
	-- Update the Publication.Entity.InformationResource table
	----------------------------------------------------------------------

	-- Determine which publications already exist
	UPDATE p
		SET p.EntityID = e.EntityID
		FROM #publications p, [Profile.Data].[Publication.Entity.InformationResource] e
		WHERE p.PMID = e.PMID and p.PMID is not null
	UPDATE p
		SET p.EntityID = e.EntityID
		FROM #publications p, [Profile.Data].[Publication.Entity.InformationResource] e
		WHERE p.MPID = e.MPID and p.MPID is not null
	CREATE NONCLUSTERED INDEX idx_entityid on #publications(EntityID)

	-- Deactivate old publications
	UPDATE e
		SET e.IsActive = 0
		FROM [Profile.Data].[Publication.Entity.InformationResource] e
		WHERE e.EntityID NOT IN (SELECT EntityID FROM #publications)

	-- Update the data for existing publications
	UPDATE e
		SET e.EntityDate = p.EntityDate,
			e.pmcid = p.pmcid,
			e.Reference = p.Reference,
			e.Source = p.Source,
			e.URL = p.URL,
			e.EntityName = p.Title,
			e.IsActive = 1,
			e.PubYear = year(p.EntityDate),
            e.YearWeight = (case when p.EntityDate is null then 0.5
                when year(p.EntityDate) <= 1901 then 0.5
                else power(cast(0.5 as float),cast(datediff(d,p.EntityDate,GetDate()) as float)/365.25/10)
                end)
		FROM #publications p, [Profile.Data].[Publication.Entity.InformationResource] e
		WHERE p.EntityID = e.EntityID and p.EntityID is not null

	-- Insert new publications
	INSERT INTO [Profile.Data].[Publication.Entity.InformationResource] (
			PMID,
			PMCID,
			MPID,
			EntityName,
			EntityDate,
			Reference,
			Source,
			URL,
			IsActive,
			PubYear,
			YearWeight
		)
		SELECT 	PMID,
				PMCID,
				MPID,
				Title,
				EntityDate,
				Reference,
				Source,
				URL,
				1 IsActive,
				PubYear = year(EntityDate),
				YearWeight = (case when EntityDate is null then 0.5
								when year(EntityDate) <= 1901 then 0.5
								else power(cast(0.5 as float),cast(datediff(d,EntityDate,GetDate()) as float)/365.25/10)
								end)
		FROM #publications
		WHERE EntityID IS NULL

 
	-- *******************************************************************
	-- *******************************************************************
	-- Update Authorship entities
	-- *******************************************************************
	-- *******************************************************************
 
 	----------------------------------------------------------------------
	-- Get a list of current Authorship records
	----------------------------------------------------------------------

	CREATE TABLE #Authorship
	(
		EntityDate DATETIME NULL ,
		authorRank INT NULL,
		numberOfAuthors INT NULL,
		authorNameAsListed VARCHAR(255) NULL,
		AuthorWeight FLOAT NULL,
		AuthorPosition VARCHAR(1) NULL,
		PubYear INT NULL ,
		YearWeight FLOAT NULL ,
		PersonID INT NULL ,
		InformationResourceID INT NULL,
		PMID INT NULL,
		IsActive BIT,
		EntityID INT
	)
 
	INSERT INTO #Authorship (EntityDate, PersonID, InformationResourceID, PMID, IsActive)
		SELECT e.EntityDate, i.PersonID, e.EntityID, e.PMID, 1 IsActive
			FROM [Profile.Data].[Publication.Entity.InformationResource] e,
				[Profile.Data].[Publication.Person.Include] i
			WHERE e.PMID = i.PMID and e.PMID is not null
	INSERT INTO #Authorship (EntityDate, PersonID, InformationResourceID, PMID, IsActive)
		SELECT e.EntityDate, i.PersonID, e.EntityID, null PMID, 1 IsActive
			FROM [Profile.Data].[Publication.Entity.InformationResource] e,
				[Profile.Data].[Publication.Person.Include] i
			WHERE (e.MPID = i.MPID) and (e.MPID is not null) and (e.PMID is null)
	CREATE NONCLUSTERED INDEX idx_person_pmid ON #Authorship(PersonID, PMID)
	CREATE NONCLUSTERED INDEX idx_person_pub ON #Authorship(PersonID, InformationResourceID)

	UPDATE a
		SET	a.authorRank=p.authorRank,
			a.numberOfAuthors=p.numberOfAuthors,
			a.authorNameAsListed=p.authorNameAsListed, 
			a.AuthorWeight=p.AuthorWeight, 
			a.AuthorPosition=p.AuthorPosition,
			a.PubYear=p.PubYear,
			a.YearWeight=p.YearWeight
		FROM #Authorship a, [Profile.Cache].[Publication.PubMed.AuthorPosition]  p
		WHERE a.PersonID = p.PersonID and a.PMID = p.PMID and a.PMID is not null
	UPDATE #authorship
		SET authorWeight = 0.5
		WHERE authorWeight IS NULL
	UPDATE #authorship
		SET authorPosition = 'U'
		WHERE authorPosition IS NULL
	UPDATE #authorship
		SET PubYear = year(EntityDate)
		WHERE PubYear IS NULL
	UPDATE #authorship
		SET	YearWeight = (case when EntityDate is null then 0.5
							when year(EntityDate) <= 1901 then 0.5
							else power(cast(0.5 as float),cast(datediff(d,EntityDate,GetDate()) as float)/365.25/10)
							end)
		WHERE YearWeight IS NULL

	----------------------------------------------------------------------
	-- Update the Publication.Authorship table
	----------------------------------------------------------------------

	-- Determine which authorships already exist
	UPDATE a
		SET a.EntityID = e.EntityID
		FROM #authorship a, [Profile.Data].[Publication.Entity.Authorship] e
		WHERE a.PersonID = e.PersonID and a.InformationResourceID = e.InformationResourceID
 	CREATE NONCLUSTERED INDEX idx_entityid on #authorship(EntityID)

	-- Deactivate old authorships
	UPDATE a
		SET a.IsActive = 0
		FROM [Profile.Data].[Publication.Entity.Authorship] a
		WHERE a.EntityID NOT IN (SELECT EntityID FROM #authorship)

	-- Update the data for existing authorships
	UPDATE e
		SET e.EntityDate = a.EntityDate,
			e.authorRank = a.authorRank,
			e.numberOfAuthors = a.numberOfAuthors,
			e.authorNameAsListed = a.authorNameAsListed,
			e.authorWeight = a.authorWeight,
			e.authorPosition = a.authorPosition,
			e.PubYear = a.PubYear,
			e.YearWeight = a.YearWeight,
			e.IsActive = 1
		FROM #authorship a, [Profile.Data].[Publication.Entity.Authorship] e
		WHERE a.EntityID = e.EntityID and a.EntityID is not null

	-- Insert new Authorships
	INSERT INTO [Profile.Data].[Publication.Entity.Authorship] (
			EntityDate,
			authorRank,
			numberOfAuthors,
			authorNameAsListed,
			authorWeight,
			authorPosition,
			PubYear,
			YearWeight,
			PersonID,
			InformationResourceID,
			IsActive
		)
		SELECT 	EntityDate,
				authorRank,
				numberOfAuthors,
				authorNameAsListed,
				authorWeight,
				authorPosition,
				PubYear,
				YearWeight,
				PersonID,
				InformationResourceID,
				IsActive
		FROM #authorship a
		WHERE EntityID IS NULL

	-- Assign an EntityName
	UPDATE [Profile.Data].[Publication.Entity.Authorship]
		SET EntityName = 'Authorship ' + CAST(EntityID as VARCHAR(50))
		WHERE EntityName is null
 
END
GO

/***
*
* Updated the import validation procedure to check that the same internalusername is not used in both the [Profile.Import].[User] and [Profile.Import].[Person] tables.
* Updated the import validation procedure to prevent incorrectly flagging short addresses.
*
***/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [Profile.Import].[ValidateProfilesImportTables]	 
AS
BEGIN
	SET NOCOUNT ON;	

	BEGIN TRY

		DECLARE @errorstring VARCHAR(2000), @ErrMsg VARCHAR(2000),@errSeverity VARCHAR(20)

		CREATE TABLE #Msg (MsgStr NVARCHAR(2000))
		DECLARE @sql NVARCHAR(max)


		--*************************************************************************************************************
		--*************************************************************************************************************
		--*** Validate column lengths and use of null values.
		--*************************************************************************************************************
		--*************************************************************************************************************

		-- Create a list of all the loading table columns and their valid lengths and types
		DECLARE @columns TABLE (
			tableName VARCHAR(50),
			columnName VARCHAR(50),
			dataType VARCHAR(50),
			maxLength INT,
			columnType VARCHAR(50)
		)
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','internalusername','string',50,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','firstname','string',50,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','middlename','string',50,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','lastname','string',50,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','displayname','string',255,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','suffix','string',50,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','addressline1','string',255,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','addressline2','string',255,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','addressline3','string',255,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','addressline4','string',255,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','addressstring','string',1000,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','city','string',100,'Not Used')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','state','string',2,'Not Used')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','zip','string',10,'Not Used')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','building','string',255,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','room','string',255,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','floor','int',null,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','latitude','decimal',null,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','longitude','decimal',null,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','phone','string',35,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','fax','string',25,'Optional') 
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','emailaddr','string',255,'Optional') 
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','isactive','bit',null,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[Person] ','isvisible','bit',null,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','internalusername','string',50,'Required') 
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','title','string',200,'Optional') 
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','emailaddr','string',200,'Dont Use')
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','primaryaffiliation','bit',null,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','affiliationorder','int',null,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','institutionname','string',500,'Optional') 
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','institutionabbreviation','string',50,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','departmentname','string',500,'Optional')  
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','departmentvisible','bit',null,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','divisionname','string',500,'Optional')  
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','facultyrank','string',100,'Optional') 
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonAffiliation]  ','facultyrankorder','tinyint',null,'Optional')  
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonFilterFlag]  ','internalusername','string',50,'Required') 
		INSERT INTO @columns VALUES ('[Profile.Import].[PersonFilterFlag]  ','personfilter','string',50,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','internalusername','string',50,'Required') 
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','firstname','string',100,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','lastname','string',100,'Required')
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','displayname','string',255,'Required') 
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','institution','string',500,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','department','string',500,'Optional')
		INSERT INTO @columns VALUES ('[Profile.Import].[User]','canbeproxy','bit',null,'Required')

		-- Check for values that are too long
		SELECT @sql = ''
		SELECT @sql = @sql + '
				INSERT INTO #Msg 
					SELECT ''ERROR: '+tableName+'.'+columnName+' has values longer than '+cast(maxLength as nvarchar(50))+' characters.''
					FROM '+tableName+'
					HAVING MAX(LEN(ISNULL('+columnName+',''''))) > '+cast(maxLength as nvarchar(50))+';'
			FROM @columns
			WHERE dataType = 'string'
		EXEC sp_executesql @sql 			 

		-- Check for values that should be numeric but are not
		SELECT @sql = ''
		SELECT @sql = @sql + '
				INSERT INTO #Msg 
					SELECT ''ERROR: '+tableName+'.'+columnName+' has values that are not numeric.''
					FROM '+tableName+' where '+tableName+'.'+columnName+' <>''''
					HAVING MIN(ISNUMERIC(ISNULL('+columnName+',0))) = 0;'
			FROM @columns
			WHERE columnName IN ('floor','assistantuserid')
		EXEC sp_executesql @sql 			 
  
		-- Check that Required columns do not have any NULLs
		SELECT @sql = ''
		SELECT @sql = @sql + '
				INSERT INTO #Msg 
					SELECT ''ERROR: '+tableName+'.'+columnName+' must contain only NULL values. It currently has at least one NOT NULL value.''
					FROM '+tableName+'
					HAVING MAX(CASE WHEN '+columnName+' IS NULL THEN 1 ELSE 0 END)=1;'
			FROM @columns
			WHERE columnType = 'Required'
		EXEC sp_executesql @sql 			 

		-- Check that Dont Use columns only have NULLs
		SELECT @sql = ''
		SELECT @sql = @sql + '
				INSERT INTO #Msg 
					SELECT ''ERROR: '+tableName+'.'+columnName+' must contain only NULL values. It currently has at least one NOT NULL value.''
					FROM '+tableName+' where '+tableName+'.'+columnName+' <>''''
					HAVING MIN(CASE WHEN '+columnName+' IS NULL THEN 1 ELSE 0 END)=0;'
			FROM @columns
			WHERE columnType = 'Dont Use'
		EXEC sp_executesql @sql 			 

		-- Check that columns do not mix NULLs and NOT NULLs
		SELECT @sql = ''
		SELECT @sql = @sql + '
				INSERT INTO #Msg 
					SELECT ''ERROR: '+tableName+'.'+columnName+' contains both null and not null values.''
					FROM '+tableName+'
					HAVING MAX(CASE WHEN '+columnName+' IS NULL THEN 1 ELSE 0 END) <> MIN(CASE WHEN '+columnName+' IS NULL THEN 1 ELSE 0 END);'
			FROM @columns
		EXEC sp_executesql @sql 			 


		--*************************************************************************************************************
		--*************************************************************************************************************
		--*** Validate data logic (duplicate values, cross-column consistency, invalid mapping, etc).
		--*************************************************************************************************************
		--*************************************************************************************************************

		-- Check for internalusername duplicates

		INSERT INTO #Msg
			SELECT 'ERROR: An internalusername is used more than once in [Profile.Import].[Person] .'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[Person]  GROUP BY internalusername HAVING COUNT(*)>1)

		INSERT INTO #Msg
			SELECT 'ERROR: An internalusername is used more than once in [Profile.Import].[User].'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[User] GROUP BY internalusername HAVING COUNT(*)>1)
				
		INSERT INTO #Msg
			SELECT 'ERROR: An internalusername is used in both [Profile.Import].[Person] and [Profile.Import].[User].'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[Person] p JOIN [Profile.Import].[User] u ON p.internalusername = u.internalusername)

		-- Check that primaryaffiliation and affiliationsort are being used correctly

		INSERT INTO #Msg
			SELECT 'ERROR: A person in [Profile.Import].[PersonAffiliation] does not have a record with primaryaffiliation=1.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] GROUP BY internalusername HAVING SUM(primaryaffiliation*1)=0)

		INSERT INTO #Msg
			SELECT 'ERROR: A person in [Profile.Import].[PersonAffiliation] has more than one record with primaryaffiliation=1.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] GROUP BY internalusername HAVING SUM(primaryaffiliation*1)>1)

		INSERT INTO #Msg
			SELECT 'ERROR: A person in [Profile.Import].[PersonAffiliation] has more than one affiliationorder values that are the same.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] GROUP BY internalusername HAVING COUNT(DISTINCT affiliationorder)<>COUNT(affiliationorder))

		-- Check that institutions are being defined correctly

	
		INSERT INTO #Msg
			SELECT 'ERROR: An institutionname in [Profile.Import].[PersonAffiliation] is NULL when either institutionfullname or institutionabbreviation is defined.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE COALESCE(institutionname,institutionabbreviation) IS NOT NULL AND institutionname IS NULL)

		INSERT INTO #Msg
			SELECT 'ERROR: An institutionabbreviation in [Profile.Import].[PersonAffiliation] is NULL when either institutionfullname or institutionname is defined.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE institutionname IS NOT NULL AND institutionabbreviation IS NULL)

		INSERT INTO #Msg
			SELECT 'ERROR: An institutionname in [Profile.Import].[PersonAffiliation] is being mapped to more than one institutionabbreviation.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE institutionname IS NOT NULL GROUP BY institutionname HAVING COUNT(DISTINCT institutionabbreviation)>1)

		INSERT INTO #Msg
			SELECT 'ERROR: An institutionabbreviation in [Profile.Import].[PersonAffiliation] is being mapped to more than one institutionname.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE institutionabbreviation IS NOT NULL GROUP BY institutionabbreviation HAVING COUNT(DISTINCT institutionname)>1)

		-- Check that departments are being defined correctly
				
		INSERT INTO #Msg
			SELECT 'ERROR: A departmentvisible in [Profile.Import].[PersonAffiliation] is NULL when a departmentname is defined.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE departmentname IS NOT NULL AND departmentvisible IS NULL)

		-- Check that divisions are being defined correctly

		-- Check that faculty ranks are being defined correctly
		INSERT INTO #Msg
			SELECT 'ERROR: A facultyrank in [Profile.Import].[PersonAffiliation] has a NULL facultyrankorder.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE facultyrank IS NOT NULL AND facultyrankorder IS NULL)

		INSERT INTO #Msg
			SELECT 'ERROR: A facultyrank in [Profile.Import].[PersonAffiliation] is being mapped to more than one facultyrankorder.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE facultyrank IS NOT NULL GROUP BY facultyrank HAVING COUNT(DISTINCT facultyrankorder)>1)

		INSERT INTO #Msg
			SELECT 'ERROR: A facultyrankorder in [Profile.Import].[PersonAffiliation] is being mapped to more than one facultyrank.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE facultyrankorder IS NOT NULL GROUP BY facultyrankorder HAVING COUNT(DISTINCT facultyrank)>1)



		--*************************************************************************************************************
		--*************************************************************************************************************
		--*** Identify items that are not errors, but might produce unexpected behavior.
		--*************************************************************************************************************
		--*************************************************************************************************************

		INSERT INTO #Msg
			SELECT 'WARNING: All records in [Profile.Import].[Person]  have isactive=0 (or IS NULL). As a result, no people will appear on the website.'
				WHERE NOT EXISTS (SELECT 1 FROM [Profile.Import].[Person]  WHERE isactive=1)

		INSERT INTO #Msg
			SELECT 'WARNING: All records in [Profile.Import].[Person]  have isvisible=0 (or IS NULL). As a result, all profile pages will show an ''Under Construction'' message.'
				WHERE NOT EXISTS (SELECT 1 FROM [Profile.Import].[Person]  WHERE isvisible=1)

		INSERT INTO #Msg
			SELECT 'WARNING: All records in [Profile.Import].[User] have canbeproxy=0 (or IS NULL). As a result, people will not be able to select any of these users to be their proxies.'
				WHERE NOT EXISTS (SELECT 1 FROM [Profile.Import].[User] WHERE canbeproxy=1)

		INSERT INTO #Msg
			SELECT 'WARNING: All [Profile.Import].[Person] .addresslineN values are NULL. As a result, no addresses will be displayed on the website.'
				FROM [Profile.Import].[Person] 
				HAVING MIN(CASE WHEN COALESCE(addressline1,addressline2,addressline3,addressline4) IS NULL THEN 1 ELSE 0 END) = 1

		INSERT INTO #Msg
			SELECT 'WARNING: All [Profile.Import].[Person] .addressstring values are NULL. As a result, geocoding will not work, and people will not be displayed on maps.'
				FROM [Profile.Import].[Person] 
				HAVING MIN(CASE WHEN addressstring IS NULL AND (latitude IS NULL or longitude IS NULL) THEN 1 ELSE 0 END) = 1

		INSERT INTO #Msg
			SELECT 'WARNING: All departments in [Profile.Import].[PersonAffiliation] have departmentvisible=0 (or IS NULL). As a result, no departments will be listed in the website search form.'
				FROM [Profile.Import].[PersonAffiliation]
				HAVING MAX(IsNull(departmentvisible*1,-1))=0

		INSERT INTO #Msg
			SELECT 'WARNING: A departmentname in [Profile.Import].[PersonAffiliation] has records with departmentvisible=0 (or IS NULL) and departmentvisible=1. The department will be visible on the website.'
				WHERE EXISTS (SELECT 1 FROM [Profile.Import].[PersonAffiliation] WHERE departmentname IS NOT NULL GROUP BY departmentname HAVING MAX(departmentvisible*1)<>MIN(departmentvisible*1))


		--*************************************************************************************************************
		--*************************************************************************************************************
		--*** Display the list of errors and warnings that were found.
		--*************************************************************************************************************
		--*************************************************************************************************************

		INSERT INTO #Msg
			SELECT 'No problems were found.'
				WHERE NOT EXISTS (SELECT 1 FROM #Msg)

		SELECT * FROM #Msg 


	END TRY
	BEGIN CATCH
		--Check success
		IF @@TRANCOUNT > 0  ROLLBACK

		-- Raise an error with the details of the exception
		SELECT @ErrMsg = '[Profile.Import].[ValidateProfilesImportTables] Failed with : ' + ERROR_MESSAGE(),
					 @ErrSeverity = ERROR_SEVERITY()

		RAISERROR(@ErrMsg, @ErrSeverity, 1)
	END CATCH	
				
END
GO


/***
*
* Education and Training Module
*
***/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [Edit.Module].[CustomEditEducationalTraining.StoreItem]
@ExistingEducationalTrainingID BIGINT=NULL, @ExistingEducationalTrainingURI VARCHAR (400)=NULL, @educationalTrainingForID BIGINT=NULL, @educationalTrainingForURI BIGINT=NULL, 
@institution VARCHAR (MAX), @location VARCHAR (MAX),  @degree VARCHAR (MAX)=NULL,
@endDate VARCHAR (MAX)=NULL, @fieldOfStudy VARCHAR (MAX), @SessionID UNIQUEIDENTIFIER=NULL, @Error BIT=NULL OUTPUT, @NodeID BIGINT=NULL OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/*
	
	This stored procedure either creates or updates an
	AwardReceipt. In both cases a label is required.
	Nodes can be specified either by ID or URI.
	
	*/
	
	SELECT @Error = 0

	-------------------------------------------------
	-- Validate and prepare variables
	-------------------------------------------------
	
	-- Convert URIs to NodeIDs
 	IF (@ExistingEducationalTrainingID IS NULL) AND (@ExistingEducationalTrainingURI IS NOT NULL)
		SELECT @ExistingEducationalTrainingID = [RDF.].fnURI2NodeID(@ExistingEducationalTrainingURI)
 	IF (@educationalTrainingForID IS NULL) AND (@educationalTrainingForURI IS NOT NULL)
		SELECT @educationalTrainingForID = [RDF.].fnURI2NodeID(@educationalTrainingForURI)

	-- Check that some operation will be performed
	IF ((@ExistingEducationalTrainingID IS NULL) AND (@educationalTrainingForID IS NULL))
	BEGIN
		SELECT @Error = 1
		RETURN
	END

	-- Convert properties to NodeIDs
	DECLARE @institutionNodeID BIGINT
	DECLARE @locationNodeID BIGINT
	DECLARE @degreeNodeID BIGINT
	DECLARE @endDateNodeID BIGINT
	DECLARE @fieldOfStudyNodeID BIGINT
	
	SELECT @institutionNodeID = NULL, @locationNodeID = NULL, @degreeNodeID = NULL, @endDateNodeID = NULL, @fieldOfStudyNodeID = NULL
	
	IF IsNull(@institution,'')<>''
		EXEC [RDF.].GetStoreNode @Value = @institution, @Language = NULL, @DataType = NULL,
			@SessionID = @SessionID, @Error = @Error OUTPUT, @NodeID = @institutionNodeID OUTPUT
	IF IsNull(@location,'')<>''
		EXEC [RDF.].GetStoreNode @Value = @location, @Language = NULL, @DataType = NULL,
			@SessionID = @SessionID, @Error = @Error OUTPUT, @NodeID = @locationNodeID OUTPUT
	IF IsNull(@degree,'')<>''
		EXEC [RDF.].GetStoreNode @Value = @degree, @Language = NULL, @DataType = NULL,
			@SessionID = @SessionID, @Error = @Error OUTPUT, @NodeID = @degreeNodeID OUTPUT
	IF IsNull(@endDate,'')<>''
		EXEC [RDF.].GetStoreNode @Value = @endDate, @Language = NULL, @DataType = NULL,
			@SessionID = @SessionID, @Error = @Error OUTPUT, @NodeID = @endDateNodeID OUTPUT
	IF IsNull(@fieldOfStudy,'')<>''
		EXEC [RDF.].GetStoreNode @Value = @fieldOfStudy, @Language = NULL, @DataType = NULL,
			@SessionID = @SessionID, @Error = @Error OUTPUT, @NodeID = @fieldOfStudyNodeID OUTPUT


	DECLARE @label nvarchar(max)
	select @label = isnull(@institution, '') + ', ' + isnull(@fieldOfStudy, '')

	-------------------------------------------------
	-- Handle required nodes and properties
	-------------------------------------------------

	-- Get an EducationalTraining with just a label
	IF (@ExistingEducationalTrainingID IS NOT NULL)
	BEGIN
		-- The EducationalTraining NodeID is the ExistingEducationalTraining
		SELECT @NodeID = @ExistingEducationalTrainingID
		-- Delete any existing properties
		EXEC [RDF.].DeleteTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://profiles.catalyst.harvard.edu/ontology/prns#trainingAtOrganization',
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		EXEC [RDF.].DeleteTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://profiles.catalyst.harvard.edu/ontology/prns#trainingLocation',
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		EXEC [RDF.].DeleteTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://vivoweb.org/ontology/core#degreeEarned',
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		EXEC [RDF.].DeleteTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://profiles.catalyst.harvard.edu/ontology/prns#endDate',
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		EXEC [RDF.].DeleteTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://vivoweb.org/ontology/core#majorField',
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		EXEC [RDF.].DeleteTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://www.w3.org/2000/01/rdf-schema#label',
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		-- Add the label
		DECLARE @labelNodeID BIGINT
		EXEC [RDF.].GetStoreNode	@Value = @label, 
									@Language = NULL,
									@DataType = NULL,
									@SessionID = @SessionID, 
									@Error = @Error OUTPUT, 
									@NodeID = @labelNodeID OUTPUT
		EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://www.w3.org/2000/01/rdf-schema#label',
									@ObjectID = @labelNodeID,
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
	END
	ELSE
	BEGIN
		-- Create a new EducationalTraining
		EXEC [RDF.].GetStoreNode	@EntityClassURI = 'http://vivoweb.org/ontology/core#EducationalTraining',
									@Label = @label,
									@ForceNewEntity = 1,
									@SessionID = @SessionID, 
									@Error = @Error OUTPUT, 
									@NodeID = @NodeID OUTPUT
		-- Link the EducationalTraining to the educationalTrainingOf
		EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
									@PredicateURI = 'http://vivoweb.org/ontology/core#educationalTrainingOf',
									@ObjectID = @educationalTrainingForID,
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
		-- Link the educationalTrainingFor to the EducationalTraining
		EXEC [RDF.].GetStoreTriple	@SubjectID = @educationalTrainingForID,
									@PredicateURI = 'http://vivoweb.org/ontology/core#educationalTraining',
									@ObjectID = @NodeID,
									@SessionID = @SessionID,
									@Error = @Error OUTPUT
	END

	-------------------------------------------------
	-- Handle optional properties
	-------------------------------------------------

	-- Add optional properties to the AwardReceipt
	IF (@NodeID IS NOT NULL) AND (@Error = 0)
	BEGIN
		IF @institutionNodeID IS NOT NULL
			EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
										@PredicateURI = 'http://profiles.catalyst.harvard.edu/ontology/prns#trainingAtOrganization',
										@ObjectID = @institutionNodeID,
										@SessionID = @SessionID,
										@Error = @Error OUTPUT
		IF @locationNodeID IS NOT NULL
			EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
										@PredicateURI = 'http://profiles.catalyst.harvard.edu/ontology/prns#trainingLocation',
										@ObjectID = @locationNodeID,
										@SessionID = @SessionID,
										@Error = @Error OUTPUT
		IF @degreeNodeID IS NOT NULL
			EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
										@PredicateURI = 'http://vivoweb.org/ontology/core#degreeEarned',
										@ObjectID = @degreeNodeID,
										@SessionID = @SessionID,
										@Error = @Error OUTPUT
		IF @endDateNodeID IS NOT NULL
			EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
										@PredicateURI = 'http://profiles.catalyst.harvard.edu/ontology/prns#endDate',
										@ObjectID = @endDateNodeID,
										@SessionID = @SessionID,
										@Error = @Error OUTPUT
		IF @fieldOfStudyNodeID IS NOT NULL
			EXEC [RDF.].GetStoreTriple	@SubjectID = @NodeID,
										@PredicateURI = 'http://vivoweb.org/ontology/core#majorField',
										@ObjectID = @fieldOfStudyNodeID,
										@SessionID = @SessionID,
										@Error = @Error OUTPUT
	END

END
GO




/***
*
* Remove Harvard Catalyst Profiles specific code
*
***/


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Search.Cache].[Private.GetNodes]
	@SearchOptions XML,
	@SessionID UNIQUEIDENTIFIER=NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
		-- interfering with SELECT statements.
		SET NOCOUNT ON;

	/*
	
	EXEC [Search.Cache].[Private.GetNodes] @SearchOptions = '
	<SearchOptions>
		<MatchOptions>
			<SearchString ExactMatch="false">options for "lung cancer" treatment</SearchString>
			<ClassURI>http://xmlns.com/foaf/0.1/Person</ClassURI>
			<SearchFiltersList>
				<SearchFilter Property="http://xmlns.com/foaf/0.1/lastName" MatchType="Left">Smit</SearchFilter>
			</SearchFiltersList>
		</MatchOptions>
		<OutputOptions>
			<Offset>0</Offset>
			<Limit>5</Limit>
			<SortByList>
				<SortBy IsDesc="1" Property="http://xmlns.com/foaf/0.1/firstName" />
				<SortBy IsDesc="0" Property="http://xmlns.com/foaf/0.1/lastName" />
			</SortByList>
		</OutputOptions>	
	</SearchOptions>
	'
		
	*/

	declare @MatchOptions xml
	declare @OutputOptions xml
	declare @SearchString varchar(500)
	declare @ClassGroupURI varchar(400)
	declare @ClassURI varchar(400)
	declare @SearchFiltersXML xml
	declare @offset bigint
	declare @limit bigint
	declare @SortByXML xml
	declare @DoExpandedSearch bit
	
	select	@MatchOptions = @SearchOptions.query('SearchOptions[1]/MatchOptions[1]'),
			@OutputOptions = @SearchOptions.query('SearchOptions[1]/OutputOptions[1]')
	
	select	@SearchString = @MatchOptions.value('MatchOptions[1]/SearchString[1]','varchar(500)'),
			@DoExpandedSearch = (case when @MatchOptions.value('MatchOptions[1]/SearchString[1]/@ExactMatch','varchar(50)') = 'true' then 0 else 1 end),
			@ClassGroupURI = @MatchOptions.value('MatchOptions[1]/ClassGroupURI[1]','varchar(400)'),
			@ClassURI = @MatchOptions.value('MatchOptions[1]/ClassURI[1]','varchar(400)'),
			@SearchFiltersXML = @MatchOptions.query('MatchOptions[1]/SearchFiltersList[1]'),
			@offset = @OutputOptions.value('OutputOptions[1]/Offset[1]','bigint'),
			@limit = @OutputOptions.value('OutputOptions[1]/Limit[1]','bigint'),
			@SortByXML = @OutputOptions.query('OutputOptions[1]/SortByList[1]')

	declare @baseURI nvarchar(400)
	select @baseURI = value from [Framework.].Parameter where ParameterID = 'baseURI'

	declare @d datetime
	select @d = GetDate()
	

	-------------------------------------------------------
	-- Parse search string and convert to fulltext query
	-------------------------------------------------------

	declare @NumberOfPhrases INT
	declare @CombinedSearchString VARCHAR(8000)
	declare @SearchString1 VARCHAR(8000)
	declare @SearchString2 VARCHAR(8000)
	declare @SearchString3 VARCHAR(8000)
	declare @SearchPhraseXML XML
	declare @SearchPhraseFormsXML XML
	declare @ParseProcessTime INT

	EXEC [Search.].[ParseSearchString]	@SearchString = @SearchString,
										@NumberOfPhrases = @NumberOfPhrases OUTPUT,
										@CombinedSearchString = @CombinedSearchString OUTPUT,
										@SearchString1 = @SearchString1 OUTPUT,
										@SearchString2 = @SearchString2 OUTPUT,
										@SearchString3 = @SearchString3 OUTPUT,
										@SearchPhraseXML = @SearchPhraseXML OUTPUT,
										@SearchPhraseFormsXML = @SearchPhraseFormsXML OUTPUT,
										@ProcessTime = @ParseProcessTime OUTPUT

	declare @PhraseList table (PhraseID int, Phrase varchar(max), ThesaurusMatch bit, Forms varchar(max))
	insert into @PhraseList (PhraseID, Phrase, ThesaurusMatch, Forms)
	select	x.value('@ID','INT'),
			x.value('.','VARCHAR(MAX)'),
			x.value('@ThesaurusMatch','BIT'),
			x.value('@Forms','VARCHAR(MAX)')
		from @SearchPhraseFormsXML.nodes('//SearchPhrase') as p(x)

	--SELECT @NumberOfPhrases, @CombinedSearchString, @SearchPhraseXML, @SearchPhraseFormsXML, @ParseProcessTime, @SearchString1, @SearchString2, @SearchString3
	--SELECT * FROM @PhraseList
	--select datediff(ms,@d,GetDate())


	-------------------------------------------------------
	-- Parse search filters
	-------------------------------------------------------

	create table #SearchFilters (
		SearchFilterID int identity(0,1) primary key,
		IsExclude bit,
		PropertyURI varchar(400),
		PropertyURI2 varchar(400),
		MatchType varchar(100),
		Value nvarchar(max),
		Predicate bigint,
		Predicate2 bigint
	)
	
	insert into #SearchFilters (IsExclude, PropertyURI, PropertyURI2, MatchType, Value, Predicate, Predicate2)	
		select t.IsExclude, t.PropertyURI, t.PropertyURI2, t.MatchType, t.Value,
				--left(t.Value,750)+(case when t.MatchType='Left' then '%' else '' end),
				t.Predicate, t.Predicate2
			from (
				select IsNull(IsExclude,0) IsExclude, PropertyURI, PropertyURI2, MatchType, Value,
					[RDF.].fnURI2NodeID(PropertyURI) Predicate,
					[RDF.].fnURI2NodeID(PropertyURI2) Predicate2
				from (
					select distinct S.x.value('@IsExclude','bit') IsExclude,
							S.x.value('@Property','varchar(400)') PropertyURI,
							S.x.value('@Property2','varchar(400)') PropertyURI2,
							S.x.value('@MatchType','varchar(100)') MatchType,
							--S.x.value('.','nvarchar(max)') Value
							--cast(S.x.query('./*') as nvarchar(max)) Value
							(case when cast(S.x.query('./*') as nvarchar(max)) <> '' then cast(S.x.query('./*') as nvarchar(max)) else S.x.value('.','nvarchar(max)') end) Value
					from @SearchFiltersXML.nodes('//SearchFilter') as S(x)
				) t
			) t
			where t.Value IS NOT NULL and t.Value <> ''
			
	declare @NumberOfIncludeFilters int
	select @NumberOfIncludeFilters = IsNull((select count(*) from #SearchFilters where IsExclude=0),0)

	-------------------------------------------------------
	-- Parse sort by options
	-------------------------------------------------------

	create table #SortBy (
		SortByID int identity(1,1) primary key,
		IsDesc bit,
		PropertyURI varchar(400),
		PropertyURI2 varchar(400),
		PropertyURI3 varchar(400),
		Predicate bigint,
		Predicate2 bigint,
		Predicate3 bigint
	)
	
	insert into #SortBy (IsDesc, PropertyURI, PropertyURI2, PropertyURI3, Predicate, Predicate2, Predicate3)	
		select IsNull(IsDesc,0), PropertyURI, PropertyURI2, PropertyURI3,
				[RDF.].fnURI2NodeID(PropertyURI) Predicate,
				[RDF.].fnURI2NodeID(PropertyURI2) Predicate2,
				[RDF.].fnURI2NodeID(PropertyURI3) Predicate3
			from (
				select S.x.value('@IsDesc','bit') IsDesc,
						S.x.value('@Property','varchar(400)') PropertyURI,
						S.x.value('@Property2','varchar(400)') PropertyURI2,
						S.x.value('@Property3','varchar(400)') PropertyURI3
				from @SortByXML.nodes('//SortBy') as S(x)
			) t

	-------------------------------------------------------
	-- Get initial list of matching nodes (before filters)
	-------------------------------------------------------

	create table #FullNodeMatch (
		NodeID bigint not null,
		Paths bigint,
		Weight float
	)

	if @CombinedSearchString <> ''
	begin

		-- Get nodes that match separate phrases
		create table #PhraseNodeMatch (
			PhraseID int not null,
			NodeID bigint not null,
			Paths bigint,
			Weight float
		)
		if (@NumberOfPhrases > 1) and (@DoExpandedSearch = 1)
		begin
			declare @PhraseSearchString varchar(8000)
			declare @loop int
			select @loop = 1
			while @loop <= @NumberOfPhrases
			begin
				select @PhraseSearchString = Forms
					from @PhraseList
					where PhraseID = @loop
				select * into #NodeRankTemp from containstable ([RDF.].[vwLiteral], value, @PhraseSearchString, 100000)
				alter table #NodeRankTemp add primary key ([Key])
				insert into #PhraseNodeMatch (PhraseID, NodeID, Paths, Weight)
					select @loop, s.NodeID, count(*) Paths, 1-exp(sum(log(case when s.Weight*(m.[Rank]*0.000999+0.001) > 0.999999 then 0.000001 else 1-s.Weight*(m.[Rank]*0.000999+0.001) end))) Weight
						from #NodeRankTemp m
							inner loop join [Search.Cache].[Private.NodeMap] s
								on s.MatchedByNodeID = m.[Key]
						group by s.NodeID
				drop table #NodeRankTemp
				select @loop = @loop + 1
			end
			--create clustered index idx_n on #PhraseNodeMatch(NodeID)
		end

		-- Get nodes that match the combined search string
		create table #TempMatchNodes (
			NodeID bigint,
			MatchedByNodeID bigint,
			Distance int,
			Paths int,
			Weight float,
			mWeight float
		)
		-- Run each search string
		if @SearchString1 <> ''
				select * into #CombinedSearch1 from containstable ([RDF.].[vwLiteral], value, @SearchString1, 100000) t
		if @SearchString2 <> ''
				select * into #CombinedSearch2 from containstable ([RDF.].[vwLiteral], value, @SearchString2, 100000) t
		if @SearchString3 <> ''
				select * into #CombinedSearch3 from containstable ([RDF.].[vwLiteral], value, @SearchString3, 100000) t
		-- Combine each search string
		create table #CombinedSearch ([key] bigint primary key, [rank] int)
		if IsNull(@SearchString1,'') <> '' and IsNull(@SearchString2,'') = '' and IsNull(@SearchString3,'') = ''
			insert into #CombinedSearch select [key], max([rank]) [rank] from #CombinedSearch1 t group by [key]
		if IsNull(@SearchString1,'') <> '' and IsNull(@SearchString2,'') <> '' and IsNull(@SearchString3,'') = ''
			insert into #CombinedSearch select [key], max([rank]) [rank] from (select * from #CombinedSearch1 union all select * from #CombinedSearch2) t group by [key]
		if IsNull(@SearchString1,'') <> '' and IsNull(@SearchString2,'') <> '' and IsNull(@SearchString3,'') <> ''
			insert into #CombinedSearch select [key], max([rank]) [rank] from (select * from #CombinedSearch1 union all select * from #CombinedSearch2 union all select * from #CombinedSearch3) t group by [key]
		-- Get the TempMatchNodes
		insert into #TempMatchNodes (NodeID, MatchedByNodeID, Distance, Paths, Weight, mWeight)
			select s.*, m.[Rank]*0.000999+0.001 mWeight
				from #CombinedSearch m
					inner loop join [Search.Cache].[Private.NodeMap] s
						on s.MatchedByNodeID = m.[key]
		-- Delete temp tables
		if @SearchString1 <> ''
				drop table #CombinedSearch1
		if @SearchString2 <> ''
				drop table #CombinedSearch2
		if @SearchString3 <> ''
				drop table #CombinedSearch3
		drop table #CombinedSearch

		-- Get nodes that match either all phrases or the combined search string
		insert into #FullNodeMatch (NodeID, Paths, Weight)
			select IsNull(a.NodeID,b.NodeID) NodeID, IsNull(a.Paths,b.Paths) Paths,
					(case when a.weight is null or b.weight is null then IsNull(a.Weight,b.Weight) else 1-(1-a.Weight)*(1-b.Weight) end) Weight
				from (
					select NodeID, exp(sum(log(Paths))) Paths, exp(sum(log(Weight))) Weight
						from #PhraseNodeMatch
						group by NodeID
						having count(*) = @NumberOfPhrases
				) a full outer join (
					select NodeID, count(*) Paths, 1-exp(sum(log(case when Weight*mWeight > 0.999999 then 0.000001 else 1-Weight*mWeight end))) Weight
						from #TempMatchNodes
						group by NodeID
				) b on a.NodeID = b.NodeID
		--select 'Text Matches Found', datediff(ms,@d,getdate())
	end
	else if (@NumberOfIncludeFilters > 0)
	begin
		insert into #FullNodeMatch (NodeID, Paths, Weight)
			select t1.Subject, 1, 1
				from #SearchFilters f
					inner join [RDF.].Triple t1
						on f.Predicate is not null
							and t1.Predicate = f.Predicate 
							and t1.ViewSecurityGroup between -30 and -1
					left outer join [Search.Cache].[Private.NodePrefix] n1
						on n1.NodeID = t1.Object
					left outer join [RDF.].Triple t2
						on f.Predicate2 is not null
							and t2.Subject = n1.NodeID
							and t2.Predicate = f.Predicate2
							and t2.ViewSecurityGroup between -30 and -1
					left outer join [Search.Cache].[Private.NodePrefix] n2
						on n2.NodeID = t2.Object
				where f.IsExclude = 0
					and 1 = (case	when (f.Predicate2 is not null) then
										(case	when f.MatchType = 'Left' then
													(case when n2.Prefix like f.Value+'%' then 1 else 0 end)
												when f.MatchType = 'In' then
													(case when n2.Prefix in (select r.x.value('.','varchar(max)') v from (select cast(f.Value as xml) x) t cross apply x.nodes('//Item') as r(x)) then 1 else 0 end)
												else
													(case when n2.Prefix = f.Value then 1 else 0 end)
												end)
									else
										(case	when f.MatchType = 'Left' then
													(case when n1.Prefix like f.Value+'%' then 1 else 0 end)
												when f.MatchType = 'In' then
													(case when n1.Prefix in (select r.x.value('.','varchar(max)') v from (select cast(f.Value as xml) x) t cross apply x.nodes('//Item') as r(x)) then 1 else 0 end)
												else
													(case when n1.Prefix = f.Value then 1 else 0 end)
												end)
									end)
					--and (case when f.Predicate2 is not null then n2.Prefix else n1.Prefix end)
					--	like f.Value
				group by t1.Subject
				having count(distinct f.SearchFilterID) = @NumberOfIncludeFilters
		delete from #SearchFilters where IsExclude = 0
		select @NumberOfIncludeFilters = 0
	end
	else if (IsNull(@ClassGroupURI,'') <> '' or IsNull(@ClassURI,'') <> '')
	begin
		insert into #FullNodeMatch (NodeID, Paths, Weight)
			select distinct n.NodeID, 1, 1
				from [Search.Cache].[Private.NodeClass] n, [Ontology.].ClassGroupClass c
				where n.Class = c._ClassNode
					and ((@ClassGroupURI is null) or (c.ClassGroupURI = @ClassGroupURI))
					and ((@ClassURI is null) or (c.ClassURI = @ClassURI))
		select @ClassGroupURI = null, @ClassURI = null
	end

	-------------------------------------------------------
	-- Run the actual search
	-------------------------------------------------------
	create table #Node (
		SortOrder bigint identity(0,1) primary key,
		NodeID bigint,
		Paths bigint,
		Weight float
	)

	insert into #Node (NodeID, Paths, Weight)
		select s.NodeID, s.Paths, s.Weight
			from #FullNodeMatch s
				inner join [Search.Cache].[Private.NodeSummary] n on
					s.NodeID = n.NodeID
					and ( IsNull(@ClassGroupURI,@ClassURI) is null or s.NodeID in (
							select NodeID
								from [Search.Cache].[Private.NodeClass] x, [Ontology.].ClassGroupClass c
								where x.Class = c._ClassNode
									and c.ClassGroupURI = IsNull(@ClassGroupURI,c.ClassGroupURI)
									and c.ClassURI = IsNull(@ClassURI,c.ClassURI)
						) )
					and ( @NumberOfIncludeFilters =
							(select count(distinct f.SearchFilterID)
								from #SearchFilters f
									inner join [RDF.].Triple t1
										on f.Predicate is not null
											and t1.Subject = s.NodeID
											and t1.Predicate = f.Predicate 
											and t1.ViewSecurityGroup between -30 and -1
									left outer join [Search.Cache].[Private.NodePrefix] n1
										on n1.NodeID = t1.Object
									left outer join [RDF.].Triple t2
										on f.Predicate2 is not null
											and t2.Subject = n1.NodeID
											and t2.Predicate = f.Predicate2
											and t2.ViewSecurityGroup between -30 and -1
									left outer join [Search.Cache].[Private.NodePrefix] n2
										on n2.NodeID = t2.Object
								where f.IsExclude = 0
									and 1 = (case	when (f.Predicate2 is not null) then
														(case	when f.MatchType = 'Left' then
																	(case when n2.Prefix like f.Value+'%' then 1 else 0 end)
																when f.MatchType = 'In' then
																	(case when n2.Prefix in (select r.x.value('.','varchar(max)') v from (select cast(f.Value as xml) x) t cross apply x.nodes('//Item') as r(x)) then 1 else 0 end)
																else
																	(case when n2.Prefix = f.Value then 1 else 0 end)
																end)
													else
														(case	when f.MatchType = 'Left' then
																	(case when n1.Prefix like f.Value+'%' then 1 else 0 end)
																when f.MatchType = 'In' then
																	(case when n1.Prefix in (select r.x.value('.','varchar(max)') v from (select cast(f.Value as xml) x) t cross apply x.nodes('//Item') as r(x)) then 1 else 0 end)
																else
																	(case when n1.Prefix = f.Value then 1 else 0 end)
																end)
													end)
									--and (case when f.Predicate2 is not null then n2.Prefix else n1.Prefix end)
									--	like f.Value
							)
						)
					and not exists (
							select *
								from #SearchFilters f
									inner join [RDF.].Triple t1
										on f.Predicate is not null
											and t1.Subject = s.NodeID
											and t1.Predicate = f.Predicate 
											and t1.ViewSecurityGroup between -30 and -1
									left outer join [Search.Cache].[Private.NodePrefix] n1
										on n1.NodeID = t1.Object
									left outer join [RDF.].Triple t2
										on f.Predicate2 is not null
											and t2.Subject = n1.NodeID
											and t2.Predicate = f.Predicate2
											and t2.ViewSecurityGroup between -30 and -1
									left outer join [Search.Cache].[Private.NodePrefix] n2
										on n2.NodeID = t2.Object
								where f.IsExclude = 1
									and 1 = (case	when (f.Predicate2 is not null) then
														(case	when f.MatchType = 'Left' then
																	(case when n2.Prefix like f.Value+'%' then 1 else 0 end)
																when f.MatchType = 'In' then
																	(case when n2.Prefix in (select r.x.value('.','varchar(max)') v from (select cast(f.Value as xml) x) t cross apply x.nodes('//Item') as r(x)) then 1 else 0 end)
																else
																	(case when n2.Prefix = f.Value then 1 else 0 end)
																end)
													else
														(case	when f.MatchType = 'Left' then
																	(case when n1.Prefix like f.Value+'%' then 1 else 0 end)
																when f.MatchType = 'In' then
																	(case when n1.Prefix in (select r.x.value('.','varchar(max)') v from (select cast(f.Value as xml) x) t cross apply x.nodes('//Item') as r(x)) then 1 else 0 end)
																else
																	(case when n1.Prefix = f.Value then 1 else 0 end)
																end)
													end)
									--and (case when f.Predicate2 is not null then n2.Prefix else n1.Prefix end)
									--	like f.Value
						)
				outer apply (
					select	max(case when SortByID=1 then AscSortBy else null end) AscSortBy1,
							max(case when SortByID=2 then AscSortBy else null end) AscSortBy2,
							max(case when SortByID=3 then AscSortBy else null end) AscSortBy3,
							max(case when SortByID=1 then DescSortBy else null end) DescSortBy1,
							max(case when SortByID=2 then DescSortBy else null end) DescSortBy2,
							max(case when SortByID=3 then DescSortBy else null end) DescSortBy3
						from (
							select	SortByID,
									(case when f.IsDesc = 1 then null
											when f.Predicate3 is not null then n3.Value
											when f.Predicate2 is not null then n2.Value
											else n1.Value end) AscSortBy,
									(case when f.IsDesc = 0 then null
											when f.Predicate3 is not null then n3.Value
											when f.Predicate2 is not null then n2.Value
											else n1.Value end) DescSortBy
								from #SortBy f
									inner join [RDF.].Triple t1
										on f.Predicate is not null
											and t1.Subject = s.NodeID
											and t1.Predicate = f.Predicate 
											and t1.ViewSecurityGroup between -30 and -1
									left outer join [RDF.].Node n1
										on n1.NodeID = t1.Object
											and n1.ViewSecurityGroup between -30 and -1
									left outer join [RDF.].Triple t2
										on f.Predicate2 is not null
											and t2.Subject = n1.NodeID
											and t2.Predicate = f.Predicate2
											and t2.ViewSecurityGroup between -30 and -1
									left outer join [RDF.].Node n2
										on n2.NodeID = t2.Object
											and n2.ViewSecurityGroup between -30 and -1
									left outer join [RDF.].Triple t3
										on f.Predicate3 is not null
											and t3.Subject = n2.NodeID
											and t3.Predicate = f.Predicate3
											and t3.ViewSecurityGroup between -30 and -1
									left outer join [RDF.].Node n3
										on n3.NodeID = t3.Object
											and n3.ViewSecurityGroup between -30 and -1
							) t
					) o
			order by	(case when o.AscSortBy1 is null then 1 else 0 end),
						o.AscSortBy1,
						(case when o.DescSortBy1 is null then 1 else 0 end),
						o.DescSortBy1 desc,
						(case when o.AscSortBy2 is null then 1 else 0 end),
						o.AscSortBy2,
						(case when o.DescSortBy2 is null then 1 else 0 end),
						o.DescSortBy2 desc,
						(case when o.AscSortBy3 is null then 1 else 0 end),
						o.AscSortBy3,
						(case when o.DescSortBy3 is null then 1 else 0 end),
						o.DescSortBy3 desc,
						s.Weight desc,
						n.ShortLabel,
						n.NodeID


	--select 'Search Nodes Found', datediff(ms,@d,GetDate())

	-------------------------------------------------------
	-- Get network counts
	-------------------------------------------------------

	declare @NumberOfConnections as bigint
	declare @MaxWeight as float
	declare @MinWeight as float

	select @NumberOfConnections = count(*), @MaxWeight = max(Weight), @MinWeight = min(Weight) 
		from #Node

	-------------------------------------------------------
	-- Get matching class groups and classes
	-------------------------------------------------------

	declare @MatchesClassGroups nvarchar(max)

	select n.NodeID, s.Class
		into #NodeClassTemp
		from #Node n
			inner join [Search.Cache].[Private.NodeClass] s
				on n.NodeID = s.NodeID
	select c.ClassGroupURI, c.ClassURI, n.NodeID
		into #NodeClass
		from #NodeClassTemp n
			inner join [Ontology.].ClassGroupClass c
				on n.Class = c._ClassNode

	;with a as (
		select ClassGroupURI, count(distinct NodeID) NumberOfNodes
			from #NodeClass s
			group by ClassGroupURI
	), b as (
		select ClassGroupURI, ClassURI, count(distinct NodeID) NumberOfNodes
			from #NodeClass s
			group by ClassGroupURI, ClassURI
	)
	select @MatchesClassGroups = replace(cast((
			select	g.ClassGroupURI "@rdf_.._resource", 
				g._ClassGroupLabel "rdfs_.._label",
				'http://www.w3.org/2001/XMLSchema#int' "prns_.._numberOfConnections/@rdf_.._datatype",
				a.NumberOfNodes "prns_.._numberOfConnections",
				g.SortOrder "prns_.._sortOrder",
				(
					select	c.ClassURI "@rdf_.._resource",
							c._ClassLabel "rdfs_.._label",
							'http://www.w3.org/2001/XMLSchema#int' "prns_.._numberOfConnections/@rdf_.._datatype",
							b.NumberOfNodes "prns_.._numberOfConnections",
							c.SortOrder "prns_.._sortOrder"
						from b, [Ontology.].ClassGroupClass c
						where b.ClassGroupURI = c.ClassGroupURI and b.ClassURI = c.ClassURI
							and c.ClassGroupURI = g.ClassGroupURI
						order by c.SortOrder
						for xml path('prns_.._matchesClass'), type
				)
			from a, [Ontology.].ClassGroup g
			where a.ClassGroupURI = g.ClassGroupURI and g.IsVisible = 1
			order by g.SortOrder
			for xml path('prns_.._matchesClassGroup'), type
		) as nvarchar(max)),'_.._',':')

	-------------------------------------------------------
	-- Get RDF of search results objects
	-------------------------------------------------------

	declare @ObjectNodesRDF nvarchar(max)

	if @NumberOfConnections > 0
	begin
		/*
			-- Alternative methods that uses GetDataRDF to get the RDF
			declare @NodeListXML xml
			select @NodeListXML = (
					select (
							select NodeID "@ID"
							from #Node
							where SortOrder >= IsNull(@offset,0) and SortOrder < IsNull(IsNull(@offset,0)+@limit,SortOrder+1)
							order by SortOrder
							for xml path('Node'), type
							)
					for xml path('NodeList'), type
				)
			exec [RDF.].GetDataRDF @NodeListXML = @NodeListXML, @expand = 1, @showDetails = 0, @returnXML = 0, @dataStr = @ObjectNodesRDF OUTPUT
		*/
		create table #OutputNodes (
			NodeID bigint primary key,
			k int
		)
		insert into #OutputNodes (NodeID,k)
			select DISTINCT NodeID,0
			from #Node
			where SortOrder >= IsNull(@offset,0) and SortOrder < IsNull(IsNull(@offset,0)+@limit,SortOrder+1)
		declare @k int
		select @k = 0
		while @k < 10
		begin
			insert into #OutputNodes (NodeID,k)
				select distinct e.ExpandNodeID, @k+1
				from #OutputNodes o, [Search.Cache].[Private.NodeExpand] e
				where o.k = @k and o.NodeID = e.NodeID
					and e.ExpandNodeID not in (select NodeID from #OutputNodes)
			if @@ROWCOUNT = 0
				select @k = 10
			else
				select @k = @k + 1
		end
		select @ObjectNodesRDF = replace(replace(cast((
				select r.RDF + ''
				from #OutputNodes n, [Search.Cache].[Private.NodeRDF] r
				where n.NodeID = r.NodeID
				order by n.NodeID
				for xml path(''), type
			) as nvarchar(max)),'_TAGLT_','<'),'_TAGGT_','>')
	end


	-------------------------------------------------------
	-- Form search results RDF
	-------------------------------------------------------

	declare @results nvarchar(max)

	select @results = ''
			+'<rdf:Description rdf:nodeID="SearchResults">'
			+'<rdf:type rdf:resource="http://profiles.catalyst.harvard.edu/ontology/prns#Network" />'
			+'<rdfs:label>Search Results</rdfs:label>'
			+'<prns:numberOfConnections rdf:datatype="http://www.w3.org/2001/XMLSchema#int">'+cast(IsNull(@NumberOfConnections,0) as nvarchar(50))+'</prns:numberOfConnections>'
			+'<prns:offset rdf:datatype="http://www.w3.org/2001/XMLSchema#int"' + IsNull('>'+cast(@offset as nvarchar(50))+'</prns:offset>',' />')
			+'<prns:limit rdf:datatype="http://www.w3.org/2001/XMLSchema#int"' + IsNull('>'+cast(@limit as nvarchar(50))+'</prns:limit>',' />')
			+'<prns:maxWeight rdf:datatype="http://www.w3.org/2001/XMLSchema#float"' + IsNull('>'+cast(@MaxWeight as nvarchar(50))+'</prns:maxWeight>',' />')
			+'<prns:minWeight rdf:datatype="http://www.w3.org/2001/XMLSchema#float"' + IsNull('>'+cast(@MinWeight as nvarchar(50))+'</prns:minWeight>',' />')
			+'<vivo:overview rdf:parseType="Literal">'
			+IsNull(cast(@SearchOptions as nvarchar(max)),'')
			+'<SearchDetails>'+IsNull(cast(@SearchPhraseXML as nvarchar(max)),'')+'</SearchDetails>'
			+IsNull('<prns:matchesClassGroupsList>'+@MatchesClassGroups+'</prns:matchesClassGroupsList>','')
			+'</vivo:overview>'
			+IsNull((select replace(replace(cast((
					select '_TAGLT_prns:hasConnection rdf:nodeID="C'+cast(SortOrder as nvarchar(50))+'" /_TAGGT_'
					from #Node
					where SortOrder >= IsNull(@offset,0) and SortOrder < IsNull(IsNull(@offset,0)+@limit,SortOrder+1)
					order by SortOrder
					for xml path(''), type
				) as nvarchar(max)),'_TAGLT_','<'),'_TAGGT_','>')),'')
			+'</rdf:Description>'
			+IsNull((select replace(replace(cast((
					select ''
						+'_TAGLT_rdf:Description rdf:nodeID="C'+cast(x.SortOrder as nvarchar(50))+'"_TAGGT_'
						+'_TAGLT_prns:connectionWeight_TAGGT_'+cast(x.Weight as nvarchar(50))+'_TAGLT_/prns:connectionWeight_TAGGT_'
						+'_TAGLT_prns:sortOrder_TAGGT_'+cast(x.SortOrder as nvarchar(50))+'_TAGLT_/prns:sortOrder_TAGGT_'
						+'_TAGLT_rdf:object rdf:resource="'+replace(n.Value,'"','')+'"/_TAGGT_'
						+'_TAGLT_rdf:type rdf:resource="http://profiles.catalyst.harvard.edu/ontology/prns#Connection" /_TAGGT_'
						+'_TAGLT_rdfs:label_TAGGT_'+(case when s.ShortLabel<>'' then ltrim(rtrim(s.ShortLabel)) else 'Untitled' end)+'_TAGLT_/rdfs:label_TAGGT_'
						+IsNull(+'_TAGLT_vivo:overview_TAGGT_'+s.ClassName+'_TAGLT_/vivo:overview_TAGGT_','')
						+'_TAGLT_/rdf:Description_TAGGT_'
					from #Node x, [RDF.].Node n, [Search.Cache].[Private.NodeSummary] s
					where x.SortOrder >= IsNull(@offset,0) and x.SortOrder < IsNull(IsNull(@offset,0)+@limit,x.SortOrder+1)
						and x.NodeID = n.NodeID
						and x.NodeID = s.NodeID
					order by x.SortOrder
					for xml path(''), type
				) as nvarchar(max)),'_TAGLT_','<'),'_TAGGT_','>')),'')
			+IsNull(@ObjectNodesRDF,'')

	declare @x as varchar(max)
	select @x = '<rdf:RDF'
	select @x = @x + ' xmlns:'+Prefix+'="'+URI+'"' 
		from [Ontology.].Namespace
	select @x = @x + ' >' + @results + '</rdf:RDF>'
	select cast(@x as xml) RDF


END

GO


/***
*
* Research Activities and Funding module
*
***/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO

CREATE TABLE [Profile.Data].[Funding.Agreement](
	[FundingAgreementID] [varchar](50) NOT NULL,
	[FundingID] [varchar](50) NULL,
	[AgreementLabel] [varchar](2000) NULL,
	[GrantAwardedBy] [varchar](1000) NULL,
	[StartDate] [date] NULL,
	[EndDate] [date] NULL,
	[PrincipalInvestigatorName] [varchar](100) NULL,
	[Abstract] [varchar](max) NULL,
	[Source] [varchar](20) NULL,
	[FundingID2] [varchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[FundingAgreementID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

CREATE TABLE [Profile.Data].[Funding.Role](
	[FundingRoleID] [varchar](50) NOT NULL,
	[PersonID] [int] NULL,
	[FundingAgreementID] [varchar](50) NULL,
	[RoleLabel] [varchar](100) NULL,
	[RoleDescription] [varchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[FundingRoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

CREATE TABLE [Profile.Data].[Funding.Add](
	[FundingRoleID] [varchar](50) NOT NULL,
	[PersonID] [int] NOT NULL,
	[FundingAgreementID] [varchar](50) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[FundingRoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

CREATE TABLE [Profile.Data].[Funding.Delete](
	[FundingRoleID] [varchar](50) NOT NULL,
	[PersonID] [int] NULL,
	[FundingAgreementID] [varchar](50) NULL,
	[Source] varchar(20) not null,
	[FundingID] [varchar](50) NULL,
	[FundingID2] [varchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[FundingRoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] 
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [Profile.Data].[Funding.AddUpdateFunding]
	@FundingRoleID VARCHAR(50),
	@PersonID INT,
	@FundingID VARCHAR(50) = NULL,
	@FundingID2 VARCHAR(50) = NULL,
	@RoleLabel VARCHAR(100) = NULL,
	@RoleDescription VARCHAR(max) = NULL,
	@AgreementLabel VARCHAR(2000) = NULL,
	@GrantAwardedBy VARCHAR(1000) = NULL,
	@StartDate DATE = NULL,
	@EndDate DATE = NULL,
	@PrincipalInvestigatorName VARCHAR(100) = NULL,
	@Abstract VARCHAR(MAX) = NULL,
	@Source VARCHAR(20),
	@UserVerified BIT = 1 --Grants populated by disambiguation should use 0 for this. 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @FundingAgreementID VARCHAR(50)

	-- Cleanup input
	SELECT
		@FundingID = NULLIF(LTRIM(RTRIM(@FundingID)),''),
		@FundingID2 = NULLIF(LTRIM(RTRIM(@FundingID2)),''),
		@RoleLabel = NULLIF(LTRIM(RTRIM(@RoleLabel)),''),
		@RoleDescription = NULLIF(LTRIM(RTRIM(@RoleDescription)),''),
		@AgreementLabel = NULLIF(LTRIM(RTRIM(@AgreementLabel)),''),
		@GrantAwardedBy = NULLIF(LTRIM(RTRIM(@GrantAwardedBy)),''),
		@StartDate = NULLIF(@StartDate,'1/1/1900'),
		@EndDate = NULLIF(@EndDate,'1/1/1900'),
		@PrincipalInvestigatorName = NULLIF(LTRIM(RTRIM(@PrincipalInvestigatorName)),''),
		@Abstract = NULLIF(LTRIM(RTRIM(@Abstract)),''),
		@Source = ISNULL(NULLIF(LTRIM(RTRIM(@Source)),''),'Custom')

	SELECT @GrantAwardedBy = 'NIH'
		WHERE @GrantAwardedBy IS NULL AND @Source = 'NIH'

	--BEGIN TRY
	--BEGIN TRANSACTION
	
	IF EXISTS (SELECT * FROM [Profile.Data].[Funding.Role] WHERE FundingRoleID = @FundingRoleID)
	BEGIN
		-- Update existing funding

		SELECT @FundingAgreementID = FundingAgreementID 
			FROM [Profile.Data].[Funding.Role] 
			WHERE FundingRoleID = @FundingRoleID

		UPDATE [Profile.Data].[Funding.Role]
			SET	RoleLabel = @RoleLabel, 
				RoleDescription = @RoleDescription
			WHERE FundingRoleID = @FundingRoleID

		UPDATE [Profile.Data].[Funding.Agreement]
			SET	AgreementLabel = @AgreementLabel,
				FundingID = @FundingID,
				GrantAwardedBy = @GrantAwardedBy,
				StartDate = @StartDate,
				EndDate = @EndDate,
				PrincipalInvestigatorName = @PrincipalInvestigatorName,
				Abstract = @Abstract
			WHERE Source = 'Custom'
				AND FundingAgreementID = @FundingAgreementID
	END 
	ELSE
	BEGIN
		-- Add new funding

		-- Check if the agreement already exists (except for custom funding)
		SELECT @FundingAgreementID = FundingAgreementID
			FROM [Profile.Data].[Funding.Agreement]
			WHERE Source = @Source AND FundingID = @FundingID
				AND Source <> 'Custom'

		-- Create the agreement if it is new
		IF @FundingAgreementID IS NULL
		BEGIN
			SELECT @FundingAgreementID = NEWID() 

			INSERT INTO [Profile.Data].[Funding.Agreement] (FundingAgreementID, [Source], FundingID, FundingID2, AgreementLabel, GrantAwardedBy, StartDate, EndDate, PrincipalInvestigatorName, Abstract) 
				SELECT @FundingAgreementID, @Source, @FundingID, @FundingID2, @AgreementLabel, @GrantAwardedBy, @StartDate, @EndDate, @PrincipalInvestigatorName, @Abstract
		END

		-- Create the role if it does not already exist
		INSERT INTO [Profile.Data].[Funding.Role] (FundingRoleID, PersonID, FundingAgreementID, RoleLabel, RoleDescription)
			SELECT @FundingRoleID, @PersonID, @FundingAgreementID, @RoleLabel, @RoleDescription
			WHERE NOT EXISTS (SELECT * FROM [Profile.Data].[Funding.Role] WHERE PersonID = @PersonID AND FundingAgreementID = @FundingAgreementID)
	END

	-- Insert into the Funding.Add table if the user is manually editing funding
	IF (@UserVerified = 1)
		IF NOT EXISTS (SELECT * FROM [Profile.Data].[Funding.Add] WHERE FundingRoleID = @FundingRoleID)
			INSERT INTO [Profile.Data].[Funding.Add] (FundingRoleID, PersonID, FundingAgreementID)
				SELECT @FundingRoleID, @PersonID, @FundingAgreementID
				FROM [Profile.Data].[Funding.Role]
				WHERE FundingRoleID = @FundingRoleID

	--COMMIT TRANSACTION
	--END TRY
	--BEGIN CATCH
		--Check success
		/*IF @@TRANCOUNT > 0  ROLLBACK
		SELECT @date=GETDATE()
		EXEC [Profile.Cache].[Process.AddAuditUpdate] @auditid=@auditid OUTPUT,@ProcessName =@proc,@ProcessEndDate=@date,@error = 1,@insert_new_record=1
		--Raise an error with the details of the exception
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY()
		RAISERROR(@ErrMsg, @ErrSeverity, 1)*/
	--END CATCH
END


GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Profile.Data].[Funding.DeleteFunding]
	@FundingRoleID varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION
		INSERT INTO [Profile.Data].[Funding.Delete] ([FundingRoleID], [PersonID], [FundingAgreementID], [Source], [FundingID], [FundingID2])
			SELECT @FundingRoleID, PersonID, r.FundingAgreementID, Source, FundingID, FundingID2
				FROM [Profile.Data].[Funding.Role] r 
					INNER JOIN [Profile.Data].[Funding.Agreement] a
						ON r.FundingAgreementID = a.FundingAgreementID
				WHERE r.FundingRoleID = @FundingRoleID
		DELETE 
			FROM [Profile.Data].[Funding.Add]
			WHERE FundingRoleID = @FundingRoleID
		DELETE 
			FROM [Profile.Data].[Funding.Role]
			WHERE FundingRoleID = @FundingRoleID
		DELETE a
			FROM [Profile.Data].[Funding.Delete] d 
				INNER JOIN [Profile.Data].[Funding.Agreement] a
					ON d.FundingAgreementID = a.FundingAgreementID
			WHERE d.FundingRoleID = @FundingRoleID
				AND NOT EXISTS (
					SELECT * 
					FROM [Profile.Data].[Funding.Role] r
					WHERE r.FundingAgreementID = a.FundingAgreementID
				)
	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		--Check success
		/*IF @@TRANCOUNT > 0  ROLLBACK
		SELECT @date=GETDATE()
		EXEC [Profile.Cache].[Process.AddAuditUpdate] @auditid=@auditid OUTPUT,@ProcessName =@proc,@ProcessEndDate=@date,@error = 1,@insert_new_record=1
		--Raise an error with the details of the exception
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrSeverity = ERROR_SEVERITY()
		RAISERROR(@ErrMsg, @ErrSeverity, 1)*/
	END CATCH
END

GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Profile.Data].[Funding.Entity.UpdateEntityOnePerson]
	@PersonID INT,
	@FundingRoleID VARCHAR(50) = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #sql (
		i INT IDENTITY(0,1) PRIMARY KEY,
		s NVARCHAR(MAX)
	)
	INSERT INTO #sql (s)
		SELECT	'EXEC [RDF.Stage].ProcessDataMap '
					+'  @DataMapID = '+CAST(DataMapID AS VARCHAR(50))
					+', @InternalIdIn = '+InternalIdIn
					+', @TurnOffIndexing=0, @SaveLog=0; '
		FROM (
			SELECT *, '''SELECT CAST(FundingRoleID AS VARCHAR(50)) FROM [Profile.Data].[Funding.Role] WHERE PersonID = '+CAST(@PersonID AS VARCHAR(50))+'''' InternalIdIn
				FROM [Ontology.].DataMap
				WHERE class = 'http://vivoweb.org/ontology/core#ResearcherRole'
					AND NetworkProperty IS NULL
					AND Property IS NULL
			UNION ALL
			SELECT *, '''' + CAST(@PersonID AS VARCHAR(50)) + '''' InternalIdIn
				FROM [Ontology.].DataMap
				WHERE class = 'http://xmlns.com/foaf/0.1/Person' 
					AND property = 'http://vivoweb.org/ontology/core#hasResearcherRole'
					AND NetworkProperty IS NULL
		) t
		ORDER BY DataMapID

	DECLARE @s NVARCHAR(MAX)
	WHILE EXISTS (SELECT * FROM #sql)
	BEGIN
		SELECT @s = s
			FROM #sql
			WHERE i = (SELECT MIN(i) FROM #sql)
		print @s
		EXEC sp_executesql @s
		DELETE
			FROM #sql
			WHERE i = (SELECT MIN(i) FROM #sql)
	END

END

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Profile.Data].[Funding.GetFundingItem]
	@FundingRoleID VARCHAR(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		ISNULL(a.Abstract,'') Abstract,
		ISNULL(a.AgreementLabel,'') AgreementLabel,
		ISNULL(a.EndDate,'1/1/1900') EndDate,
		ISNULL(a.Source,'') Source,
		ISNULL(a.FundingID,'') FundingID,
		ISNULL(a.FundingID2,'') FundingID2,
		ISNULL(a.GrantAwardedBy,'') GrantAwardedBy,
		ISNULL(r.FundingRoleID,'') FundingRoleID,
		ISNULL(r.PersonID,'') PersonID,
		ISNULL(a.PrincipalInvestigatorName,'') PrincipalInvestigatorName,
		ISNULL(r.RoleDescription,'') RoleDescription,
		ISNULL(r.RoleLabel,'') RoleLabel,
		ISNULL(a.StartDate,'1/1/1900') StartDate,
		'' SponsorAwardID
	FROM [Profile.Data].[Funding.Role] r 
		INNER JOIN [Profile.Data].[Funding.Agreement] a
			ON r.FundingAgreementID = a.FundingAgreementID
				AND r.FundingRoleID = @FundingRoleID

END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [Profile.Data].[Funding.GetPersonFunding]
	@PersonID INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		ISNULL(a.Abstract,'') Abstract,
		ISNULL(a.AgreementLabel,'') AgreementLabel,
		ISNULL(a.EndDate,'1/1/1900') EndDate,
		ISNULL(a.Source,'') Source,
		ISNULL(a.FundingID,'') FundingID,
		ISNULL(a.FundingID2,'') FundingID2,
		ISNULL(a.GrantAwardedBy,'') GrantAwardedBy,
		ISNULL(r.FundingRoleID,'') FundingRoleID,
		ISNULL(r.PersonID,'') PersonID,
		ISNULL(a.PrincipalInvestigatorName,'') PrincipalInvestigatorName,
		ISNULL(r.RoleDescription,'') RoleDescription,
		ISNULL(r.RoleLabel,'') RoleLabel,
		ISNULL(a.StartDate,'1/1/1900') StartDate,
		'' SponsorAwardID
	FROM [Profile.Data].[Funding.Role] r 
		INNER JOIN [Profile.Data].[Funding.Agreement] a
			ON r.FundingAgreementID = a.FundingAgreementID
				AND r.PersonID = @PersonID
	ORDER BY StartDate, EndDate, FundingID

END

GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [Ontology.].[UpdateDerivedFields]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Triple
	UPDATE o
		SET	_SubjectNode = [RDF.].fnURI2NodeID(subject),
			_PredicateNode = [RDF.].fnURI2NodeID(predicate),
			_ObjectNode = [RDF.].fnURI2NodeID(object),
			_TripleID = NULL
		FROM [Ontology.Import].[Triple] o
	UPDATE o
		SET o._TripleID = r.TripleID
		FROM [Ontology.Import].[Triple] o, [RDF.].Triple r
		WHERE o._SubjectNode = r.Subject AND o._PredicateNode = r.Predicate AND o._ObjectNode = r.Object

	-- DataMap
	UPDATE o
		SET	_ClassNode = [RDF.].fnURI2NodeID(Class),
			_NetworkPropertyNode = [RDF.].fnURI2NodeID(NetworkProperty),
			_PropertyNode = [RDF.].fnURI2NodeID(property)
		FROM [Ontology.].DataMap o

	-- ClassProperty
	UPDATE o
		SET	_ClassNode = [RDF.].fnURI2NodeID(Class),
			_NetworkPropertyNode = [RDF.].fnURI2NodeID(NetworkProperty),
			_PropertyNode = [RDF.].fnURI2NodeID(property),
			_TagName = (select top 1 n.Prefix+':'+substring(o.property,len(n.URI)+1,len(o.property)) t
						from [Ontology.].Namespace n
						where o.property like n.uri+'%'
						)
		FROM [Ontology.].ClassProperty o
	UPDATE e
		SET e._PropertyLabel = o.value
		FROM [ontology.].ClassProperty e
			LEFT OUTER JOIN [RDF.].[Triple] t
				ON e._PropertyNode = t.subject AND t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#label') 
			LEFT OUTER JOIN [RDF.].[Node] o
				ON t.object = o.nodeid
	UPDATE e
		SET e._ObjectType = (CASE WHEN o.value = 'http://www.w3.org/2002/07/owl#ObjectProperty' THEN 0 ELSE 1 END)
		FROM [ontology.].ClassProperty e
			LEFT OUTER JOIN [RDF.].[Triple] t
				ON e._PropertyNode = t.subject AND t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') 
			LEFT OUTER JOIN [RDF.].[Node] o
				ON t.object = o.nodeid and o.value in ('http://www.w3.org/2002/07/owl#DatatypeProperty','http://www.w3.org/2002/07/owl#ObjectProperty')

	-- ClassGroup
	UPDATE o
		SET	_ClassGroupNode = [RDF.].fnURI2NodeID(ClassGroupURI)
		FROM [Ontology.].ClassGroup o
	UPDATE e
		SET e._ClassGroupLabel = o.value
		FROM [ontology.].ClassGroup e
			LEFT OUTER JOIN [RDF.].[Triple] t
				ON e._ClassGroupNode = t.subject AND t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#label') 
			LEFT OUTER JOIN [RDF.].[Node] o
				ON t.object = o.nodeid

	-- ClassGroupClass
	UPDATE o
		SET	_ClassGroupNode = [RDF.].fnURI2NodeID(ClassGroupURI),
			_ClassNode = [RDF.].fnURI2NodeID(ClassURI)
		FROM [Ontology.].ClassGroupClass o
	UPDATE e
		SET e._ClassLabel = o.value
		FROM [ontology.].ClassGroupClass e
			LEFT OUTER JOIN [RDF.].[Triple] t
				ON e._ClassNode = t.subject AND t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#label') 
			LEFT OUTER JOIN [RDF.].[Node] o
				ON t.object = o.nodeid
				
	-- ClassTreeDepth
	declare @ClassDepths table (
		NodeID bigint,
		SubClassOf bigint,
		Depth int,
		ClassURI varchar(400),
		ClassName varchar(400)
	)
	;with x as (
		select t.subject NodeID, 
			max(case when w.subject is null then null else v.object end) SubClassOf
		from [RDF.].Triple t
			left outer join [RDF.].Triple v
				on v.subject = t.subject 
				and v.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#subClassOf')
			left outer join [RDF.].Triple w
				on w.subject = v.object
				and w.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') 
				and w.object = [RDF.].fnURI2NodeID('http://www.w3.org/2002/07/owl#Class')
		where t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') 
			and t.object = [RDF.].fnURI2NodeID('http://www.w3.org/2002/07/owl#Class') 
		group by t.subject
	)
	insert into @ClassDepths (NodeID, SubClassOf, Depth, ClassURI)
		select x.NodeID, x.SubClassOf, (case when x.SubClassOf is null then 0 else null end) Depth, n.Value
		from x, [RDF.].Node n
		where x.NodeID = n.NodeID
	;with a as (
		select NodeID, SubClassOf, Depth
			from @ClassDepths
		union all
		select b.NodeID, IsNull(a.NodeID,b.SubClassOf), a.Depth+1
			from a, @ClassDepths b
			where b.SubClassOf = a.NodeID
				and a.Depth is not null
				and b.Depth is null
	), b as (
		select NodeID, SubClassOf, Max(Depth) Depth
		from a
		group by NodeID, SubClassOf
	)
	update c
		set c.Depth = b.Depth
		from @ClassDepths c, b
		where c.NodeID = b.NodeID
	;with a as (
		select c.NodeID, max(n.Value) ClassName
			from @ClassDepths c
				inner join [RDF.].Triple t
					on t.subject = c.NodeID
						and t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#label')
				inner join [RDF.].Node n
					on t.object = n.NodeID
			group by c.NodeID
	)
	update c
		set c.ClassName = a.ClassName
		from @ClassDepths c, a
		where c.NodeID = a.NodeID
	truncate table [Ontology.].ClassTreeDepth
	insert into [Ontology.].ClassTreeDepth (Class, _TreeDepth, _ClassNode, _ClassName)
		select ClassURI, Depth, NodeID, ClassName
			from @ClassDepths

	-- PropertyGroup
	UPDATE o
		SET	_PropertyGroupNode = [RDF.].fnURI2NodeID(PropertyGroupURI)
		FROM [Ontology.].PropertyGroup o
	UPDATE e
		SET e._PropertyGroupLabel = o.value
		FROM [ontology.].PropertyGroup e
			LEFT OUTER JOIN [RDF.].[Triple] t
				ON e._PropertyGroupNode = t.subject AND t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#label') 
			LEFT OUTER JOIN [RDF.].[Node] o
				ON t.object = o.nodeid

	-- PropertyGroupProperty
	UPDATE o
		SET	_PropertyGroupNode = [RDF.].fnURI2NodeID(PropertyGroupURI),
			_PropertyNode = [RDF.].fnURI2NodeID(PropertyURI),
			_TagName = (select top 1 n.Prefix+':'+substring(o.PropertyURI,len(n.URI)+1,len(o.PropertyURI)) t
						from [Ontology.].Namespace n
						where o.PropertyURI like n.uri+'%'
						)
		FROM [Ontology.].PropertyGroupProperty o
	UPDATE e
		SET e._PropertyLabel = o.value
		FROM [ontology.].PropertyGroupProperty e
			LEFT OUTER JOIN [RDF.].[Triple] t
				ON e._PropertyNode = t.subject AND t.predicate = [RDF.].fnURI2NodeID('http://www.w3.org/2000/01/rdf-schema#label') 
			LEFT OUTER JOIN [RDF.].[Node] o
				ON t.object = o.nodeid


	-- Presentation
	UPDATE o
		SET	_SubjectNode = [RDF.].fnURI2NodeID(subject),
			_PredicateNode = [RDF.].fnURI2NodeID(predicate),
			_ObjectNode = [RDF.].fnURI2NodeID(object)
		FROM [Ontology.Presentation].[XML] o


	-- Funding
	UPDATE [Ontology.].[ClassProperty]
		SET _PropertyLabel = 'research activities and funding' --'research activities'
		WHERE Class='http://xmlns.com/foaf/0.1/Person' AND Property='http://vivoweb.org/ontology/core#hasResearcherRole' AND NetworkProperty IS NULL


	-- select * from [Ontology.Import].[Triple]
	-- select * from [Ontology.].ClassProperty
	-- select * from [Ontology.].ClassGroup
	-- select * from [Ontology.].ClassGroupClass
	-- select * from [Ontology.].ClassTreeDepth
	-- select * from [Ontology.].PropertyGroup
	-- select * from [Ontology.].PropertyGroupProperty
	-- select * from [Ontology.Presentation].[XML]

END
GO
