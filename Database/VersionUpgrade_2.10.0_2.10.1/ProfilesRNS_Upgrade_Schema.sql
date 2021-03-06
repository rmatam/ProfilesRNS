/*
Run this script on:

        Profiles 2.10.0   -  This database will be modified

to synchronize it with:

        Profiles 2.10.1

You are recommended to back up your database before running this script

Details of which objects have changed can be found in the release notes.
If you have made changes to existing tables or stored procedures in profiles, you may need to merge changes individually. 

*/

ALTER TABLE [Profile.Data].[Publication.PubMed.Keyword] DROP CONSTRAINT [PK_pm_pubs_keywords]
ALTER TABLE [Profile.Data].[Publication.PubMed.Keyword] ALTER COLUMN [Keyword] [varchar] (500) not null
ALTER TABLE [Profile.Data].[Publication.PubMed.Keyword] ADD CONSTRAINT [PK_pm_pubs_keywords] PRIMARY KEY CLUSTERED  ([pmid], [Keyword])
GO
ALTER TABLE [Profile.Data].[Publication.PubMed.Author] ALTER COLUMN [Affiliation] [varchar] (8000) 
ALTER TABLE [Profile.Data].[Publication.PubMed.General] ALTER COLUMN [Affiliation] [varchar] (8000)
ALTER TABLE [Profile.Data].[Publication.PubMed.Author.Stage] ALTER COLUMN [Affiliation] [varchar] (8000) 
ALTER TABLE [Profile.Data].[Publication.PubMed.General.Stage] ALTER COLUMN [Affiliation] [varchar] (8000)
GO



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [Profile.Import].[LoadProfilesData]
    (
      @use_internalusername_as_pkey BIT = 0
    )
AS 
    BEGIN
        SET NOCOUNT ON;	


	-- Start Transaction. Log load failures, roll back transaction on error.
        BEGIN TRY
            BEGIN TRAN				 

            DECLARE @ErrMsg NVARCHAR(4000) ,
                @ErrSeverity INT


						-- Department
            INSERT  INTO [Profile.Data].[Organization.Department]
                    ( departmentname ,
                      visible
                    )
                    SELECT DISTINCT
                            departmentname ,
                            1
                    FROM    [Profile.Import].PersonAffiliation a
                    WHERE   departmentname IS NOT NULL
                            AND departmentname NOT IN (
                            SELECT  departmentname
                            FROM    [Profile.Data].[Organization.Department] )


						-- institution
            INSERT  INTO [Profile.Data].[Organization.Institution]
                    ( InstitutionName ,
                      InstitutionAbbreviation
										
                    )
                    SELECT  INSTITUTIONNAME ,
                            INSTITUTIONABBREVIATION
                    FROM    ( SELECT    INSTITUTIONNAME ,
                                        INSTITUTIONABBREVIATION ,
                                        COUNT(*) CNT ,
                                        ROW_NUMBER() OVER ( PARTITION BY institutionname ORDER BY SUM(CASE
                                                              WHEN INSTITUTIONABBREVIATION = ''
                                                              THEN 0
                                                              ELSE 1
                                                              END) DESC ) rank
                              FROM      [Profile.Import].PersonAffiliation
                              GROUP BY  INSTITUTIONNAME ,
                                        INSTITUTIONABBREVIATION
                            ) A
                    WHERE   rank = 1
                            AND institutionname <> ''
                            AND NOT EXISTS ( SELECT b.institutionname
                                             FROM   [Profile.Data].[Organization.Institution] b
                                             WHERE  b.institutionname = a.institutionname )


						-- division
            INSERT  INTO [Profile.Data].[Organization.Division]
                    ( DivisionName  
										
                    )
                    SELECT DISTINCT
                            divisionname
                    FROM    [Profile.Import].PersonAffiliation a
                    WHERE   divisionname IS NOT NULL
                            AND NOT EXISTS ( SELECT b.divisionname
                                             FROM   [Profile.Data].[Organization.Division] b
                                             WHERE  b.divisionname = a.divisionname )



					-- Flag deleted people
			DECLARE @deletedPersonIDTable TABLE (PersonID int)
            
			UPDATE  [Profile.Data].Person
            SET     ISactive = 0
			OUTPUT inserted.PersonID into @deletedPersonIDTable
            WHERE  IsActive <> 0 AND internalusername NOT IN (
                    SELECT  internalusername
                    FROM    [Profile.Import].Person where isactive = 1)
			
			INSERT INTO [Framework.].[Log.Activity] (userId, personId, methodName, property, privacyCode, param1, param2) 
			SELECT 0, PersonID, '[Profile.Import].[LoadProfilesData]', null, null, 'Person Delete', null FROM @deletedPersonIDTable

					-- Update person/user records where data has changed. 
			DECLARE @updatedPersonIDTable TABLE (PersonID int)
            
			UPDATE  p
            SET     p.firstname = lp.firstname ,
                    p.lastname = lp.lastname ,
                    p.middlename = lp.middlename ,
                    p.displayname = lp.displayname ,
                    p.suffix = lp.suffix ,
                    p.addressline1 = lp.addressline1 ,
                    p.addressline2 = lp.addressline2 ,
                    p.addressline3 = lp.addressline3 ,
                    p.addressline4 = lp.addressline4 ,
                    p.city = lp.city ,
                    p.state = lp.state ,
                    p.zip = lp.zip ,
                    p.building = lp.building ,
                    p.room = lp.room ,
                    p.phone = lp.phone ,
                    p.fax = lp.fax ,
                    p.EmailAddr = lp.EmailAddr ,
                    p.AddressString = lp.AddressString ,
                    p.isactive = lp.isactive ,
                    p.visible = lp.isvisible
					OUTPUT inserted.PersonID into @updatedPersonIDTable
            FROM    [Profile.Data].Person p
                    JOIN [Profile.Import].Person lp ON lp.internalusername = p.internalusername
                                                       AND ( ISNULL(lp.firstname,
                                                              '') <> ISNULL(p.firstname,
                                                              '')
                                                             OR ISNULL(lp.lastname,
                                                              '') <> ISNULL(p.lastname,
                                                              '')
                                                             OR ISNULL(lp.middlename,
                                                              '') <> ISNULL(p.middlename,
                                                              '')
                                                             OR ISNULL(lp.displayname,
                                                              '') <> ISNULL(p.displayname,
                                                              '')
                                                             OR ISNULL(lp.suffix,
                                                              '') <> ISNULL(p.suffix,
                                                              '')
                                                             OR ISNULL(lp.addressline1,
                                                              '') <> ISNULL(p.addressline1,
                                                              '')
                                                             OR ISNULL(lp.addressline2,
                                                              '') <> ISNULL(p.addressline2,
                                                              '')
                                                             OR ISNULL(lp.addressline3,
                                                              '') <> ISNULL(p.addressline3,
                                                              '')
                                                             OR ISNULL(lp.addressline4,
                                                              '') <> ISNULL(p.addressline4,
                                                              '')
                                                             OR ISNULL(lp.city,
                                                              '') <> ISNULL(p.city,
                                                              '')
                                                             OR ISNULL(lp.state,
                                                              '') <> ISNULL(p.state,
                                                              '')
                                                             OR ISNULL(lp.zip,
                                                              '') <> ISNULL(p.zip,
                                                              '')
                                                             OR ISNULL(lp.building,
                                                              '') <> ISNULL(p.building,
                                                              '')
                                                             OR ISNULL(lp.room,
                                                              '') <> ISNULL(p.room,
                                                              '')
                                                             OR ISNULL(lp.phone,
                                                              '') <> ISNULL(p.phone,
                                                              '')
                                                             OR ISNULL(lp.fax,
                                                              '') <> ISNULL(p.fax,
                                                              '')
                                                             OR ISNULL(lp.EmailAddr,
                                                              '') <> ISNULL(p.EmailAddr,
                                                              '')
                                                             OR ISNULL(lp.AddressString,
                                                              '') <> ISNULL(p.AddressString,
                                                              '')
                                                             OR ISNULL(lp.Isactive,
                                                              '') <> ISNULL(p.Isactive,
                                                              '')
                                                             OR ISNULL(lp.isvisible,
                                                              '') <> ISNULL(p.visible,
                                                              '')
                                                           ) 

			INSERT INTO [Framework.].[Log.Activity] (userId, personId, methodName, property, privacyCode, param1, param2) 
			SELECT 0, PersonID, '[Profile.Import].[LoadProfilesData]', null, null, 'Person Update', null FROM @updatedPersonIDTable
						-- Update changed user info
            UPDATE  u
            SET     u.firstname = up.firstname ,
                    u.lastname = up.lastname ,
                    u.displayname = up.displayname ,
                    u.institution = up.institution ,
                    u.department = up.department ,
                    u.emailaddr = up.emailaddr
            FROM    [User.Account].[User] u
                    JOIN [Profile.Import].[User] up ON up.internalusername = u.internalusername
                                                       AND ( ISNULL(up.firstname,
                                                              '') <> ISNULL(u.firstname,
                                                              '')
                                                             OR ISNULL(up.lastname,
                                                              '') <> ISNULL(u.lastname,
                                                              '')
                                                             OR ISNULL(up.displayname,
                                                              '') <> ISNULL(u.displayname,
                                                              '')
                                                             OR ISNULL(up.institution,
                                                              '') <> ISNULL(u.institution,
                                                              '')
                                                             OR ISNULL(up.department,
                                                              '') <> ISNULL(u.department,
                                                              '')
                                                             OR ISNULL(up.emailaddr,
                                                              '') <> ISNULL(u.emailaddr,
                                                              '')
                                                           )

					-- Remove Affiliations that have changed, so they'll be re-added
            SELECT DISTINCT
                    COALESCE(p.internalusername, pa.internalusername) internalusername
            INTO    #affiliations
            FROM    [Profile.Cache].[Person.Affiliation] cpa
            JOIN	[Profile.Data].Person p ON p.personid = cpa.personid
       FULL JOIN	[Profile.Import].PersonAffiliation pa ON pa.internalusername = p.internalusername
                                                              AND  pa.affiliationorder =  cpa.sortorder  
                                                              AND pa.primaryaffiliation = cpa.isprimary  
                                                              AND pa.title = cpa.title  
                                                              AND pa.institutionabbreviation =  cpa.institutionabbreviation  
                                                              AND pa.departmentname =  cpa.departmentname  
                                                              AND pa.divisionname = cpa.divisionname 
                                                              AND pa.facultyrank  = cpa.facultyrank
                                                              
            WHERE   pa.internalusername IS NULL
                    OR cpa.personid IS NULL

            DELETE  FROM [Profile.Data].[Person.Affiliation]
            WHERE   personid IN ( SELECT    personid
                                  FROM      [Profile.Data].Person
                                  WHERE     internalusername IN ( SELECT
                                                              internalusername
                                                              FROM
                                                              #affiliations ) )

					-- Remove Filters that have changed, so they'll be re-added
            SELECT  internalusername ,
                    personfilter
            INTO    #filter
            FROM    [Profile.Data].[Person.FilterRelationship] pfr
                    JOIN [Profile.Data].Person p ON p.personid = pfr.personid
                    JOIN [Profile.Data].[Person.Filter] pf ON pf.personfilterid = pfr.personfilterid
            CREATE CLUSTERED INDEX tmp ON #filter(internalusername)
            DELETE  FROM [Profile.Data].[Person.FilterRelationship]
            WHERE   personid IN (
                    SELECT  personid
                    FROM    [Profile.Data].Person
                    WHERE   InternalUsername IN (
                            SELECT  COALESCE(a.internalusername,
                                             p.internalusername)
                            FROM    [Profile.Import].PersonFilterFlag pf
                                    JOIN [Profile.Import].Person p ON p.internalusername = pf.internalusername
                                    FULL JOIN #filter a ON a.internalusername = p.internalusername
                                                           AND a.personfilter = pf.personfilter
                            WHERE   a.internalusername IS NULL
                                    OR p.internalusername IS NULL ) )






					-- user
            IF @use_internalusername_as_pkey = 0 
                BEGIN
                    INSERT  INTO [User.Account].[User]
                            ( IsActive ,
                              CanBeProxy ,
                              FirstName ,
                              LastName ,
                              DisplayName ,
                              Institution ,
                              Department ,
                              InternalUserName ,
                              emailaddr 
						        
                            )
                            SELECT  1 ,
                                    canbeproxy ,
                                    ISNULL(firstname, '') ,
                                    ISNULL(lastname, '') ,
                                    ISNULL(displayname, '') ,
                                    institution ,
                                    department ,
                                    InternalUserName ,
                                    emailaddr
                            FROM    [Profile.Import].[User] u
                            WHERE   NOT EXISTS ( SELECT *
                                                 FROM   [User.Account].[User] b
                                                 WHERE  b.internalusername = u.internalusername )
                            UNION
                            SELECT  1 ,
                                    1 ,
                                    ISNULL(firstname, '') ,
                                    ISNULL(lastname, '') ,
                                    ISNULL(displayname, '') ,
                                    institutionname ,
                                    departmentname ,
                                    u.InternalUserName ,
                                    u.emailaddr
                            FROM    [Profile.Import].Person u
                                    LEFT JOIN [Profile.Import].PersonAffiliation pa ON pa.internalusername = u.internalusername
                                                              AND pa.primaryaffiliation = 1
                            WHERE   NOT EXISTS ( SELECT *
                                                 FROM   [User.Account].[User] b
                                                 WHERE  b.internalusername = u.internalusername )
                END
            ELSE 
                BEGIN
                    SET IDENTITY_INSERT [User.Account].[User] ON 

                    INSERT  INTO [User.Account].[User]
                            ( userid ,
                              IsActive ,
                              CanBeProxy ,
                              FirstName ,
                              LastName ,
                              DisplayName ,
                              Institution ,
                              Department ,
                              InternalUserName ,
                              emailaddr 
						        
                            )
                            SELECT  u.internalusername ,
                                    1 ,
                                    canbeproxy ,
                                    ISNULL(firstname, '') ,
                                    ISNULL(lastname, '') ,
                                    ISNULL(displayname, '') ,
                                    institution ,
                                    department ,
                                    InternalUserName ,
                                    emailaddr
                            FROM    [Profile.Import].[User] u
                            WHERE   NOT EXISTS ( SELECT *
                                                 FROM   [User.Account].[User] b
                                                 WHERE  b.internalusername = u.internalusername )
                            UNION ALL
                            SELECT  u.internalusername ,
                                    1 ,
                                    1 ,
                                    ISNULL(firstname, '') ,
                                    ISNULL(lastname, '') ,
                                    ISNULL(displayname, '') ,
                                    institutionname ,
                                    departmentname ,
                                    u.InternalUserName ,
                                    u.emailaddr
                            FROM    [Profile.Import].Person u
                                    LEFT JOIN [Profile.Import].PersonAffiliation pa ON pa.internalusername = u.internalusername
                                                              AND pa.primaryaffiliation = 1
                            WHERE   NOT EXISTS ( SELECT *
                                                 FROM   [User.Account].[User] b
                                                 WHERE  b.internalusername = u.internalusername )
                                    AND NOT EXISTS ( SELECT *
                                                     FROM   [Profile.Import].[User] b
                                                     WHERE  b.internalusername = u.internalusername )

                    SET IDENTITY_INSERT [User.Account].[User] OFF
                END

					-- faculty ranks
            INSERT  INTO [Profile.Data].[Person.FacultyRank]
                    ( FacultyRank ,
                      FacultyRankSort ,
                      Visible
					        
                    )
                    SELECT DISTINCT
                            facultyrank ,
                            facultyrankorder ,
                            1
                    FROM    [Profile.Import].PersonAffiliation p
                    WHERE   NOT EXISTS ( SELECT *
                                         FROM   [Profile.Data].[Person.FacultyRank] a
                                         WHERE  a.facultyrank = p.facultyrank )

					-- person
			DECLARE @newPersonIDTable TABLE (personID INT)	
            IF @use_internalusername_as_pkey = 0 
                BEGIN
								
                    INSERT  INTO [Profile.Data].Person
                            ( UserID ,
                              FirstName ,
                              LastName ,
                              MiddleName ,
                              DisplayName ,
                              Suffix ,
                              IsActive ,
                              EmailAddr ,
                              Phone ,
                              Fax ,
                              AddressLine1 ,
                              AddressLine2 ,
                              AddressLine3 ,
                              AddressLine4 ,
                              city ,
                              state ,
                              zip ,
                              Building ,
                              Floor ,
                              Room ,
                              AddressString ,
                              Latitude ,
                              Longitude ,
                              FacultyRankID ,
                              InternalUsername ,
                              Visible
						        
                            )
							OUTPUT inserted.PersonID into @newPersonIDTable
                            SELECT  UserID ,
                                    ISNULL(p.FirstName, '') ,
                                    ISNULL(p.LastName, '') ,
                                    ISNULL(p.MiddleName, '') ,
                                    ISNULL(p.DisplayName, '') ,
                                    ISNULL(Suffix, '') ,
                                    p.IsActive ,
                                    p.EmailAddr ,
                                    Phone ,
                                    Fax ,
                                    AddressLine1 ,
                                    AddressLine2 ,
                                    AddressLine3 ,
                                    AddressLine4 ,
                                    city ,
                                    state ,
                                    zip ,
                                    Building ,
                                    Floor ,
                                    Room ,
                                    AddressString ,
                                    Latitude ,
                                    Longitude ,
                                    FacultyRankID ,
                                    p.InternalUsername ,
                                    p.isvisible
                            FROM    [Profile.Import].Person p
                                    OUTER APPLY ( SELECT TOP 1
                                                            internalusername ,
                                                            facultyrankid ,
                                                            facultyranksort
                                                  FROM      [Profile.import].[PersonAffiliation] pa
                                                            JOIN [Profile.Data].[Person.FacultyRank] fr ON fr.facultyrank = pa.facultyrank
                                                  WHERE     pa.internalusername = p.internalusername
                                                  ORDER BY  facultyranksort ASC
                                                ) a
                                    JOIN [User.Account].[User] u ON u.internalusername = p.internalusername
                            WHERE   NOT EXISTS ( SELECT *
                                                 FROM   [Profile.Data].Person b
                                                 WHERE  b.internalusername = p.internalusername )	   
                END
            ELSE 
                BEGIN
						
                    SET IDENTITY_INSERT [Profile.Data].Person ON
                    INSERT  INTO [Profile.Data].Person
                            ( personid ,
                              UserID ,
                              FirstName ,
                              LastName ,
                              MiddleName ,
                              DisplayName ,
                              Suffix ,
                              IsActive ,
                              EmailAddr ,
                              Phone ,
                              Fax ,
                              AddressLine1 ,
                              AddressLine2 ,
                              AddressLine3 ,
                              AddressLine4 ,
                              Building ,
                              Floor ,
                              Room ,
                              AddressString ,
                              Latitude ,
                              Longitude ,
                              FacultyRankID ,
                              InternalUsername ,
                              Visible
						        
                            )
							OUTPUT inserted.PersonID into @newPersonIDTable
                            SELECT  p.internalusername ,
                                    userid ,
                                    ISNULL(p.FirstName, '') ,
                                    ISNULL(p.LastName, '') ,
                                    ISNULL(p.MiddleName, '') ,
                                    ISNULL(p.DisplayName, '') ,
                                    ISNULL(Suffix, '') ,
                                    p.IsActive ,
                                    p.EmailAddr ,
                                    Phone ,
                                    Fax ,
                                    AddressLine1 ,
                                    AddressLine2 ,
                                    AddressLine3 ,
                                    AddressLine4 ,
                                    Building ,
                                    Floor ,
                                    Room ,
                                    AddressString ,
                                    Latitude ,
                                    Longitude ,
                                    FacultyRankID ,
                                    p.InternalUsername ,
                                    p.isvisible
                            FROM    [Profile.Import].Person p
                                    OUTER APPLY ( SELECT TOP 1
                                                            internalusername ,
                                                            facultyrankid ,
                                                            facultyranksort
                                                  FROM      [Profile.import].[PersonAffiliation] pa
                                                            JOIN [Profile.Data].[Person.FacultyRank] fr ON fr.facultyrank = pa.facultyrank
                                                  WHERE     pa.internalusername = p.internalusername
                                                  ORDER BY  facultyranksort ASC
                                                ) a
                                    JOIN [User.Account].[User] u ON u.internalusername = p.internalusername
                            WHERE   NOT EXISTS ( SELECT *
                                                 FROM   [Profile.Data].Person b
                                                 WHERE  b.internalusername = p.internalusername )  
                    SET IDENTITY_INSERT [Profile.Data].Person OFF

                END

			INSERT INTO [Framework.].[Log.Activity] (userId, personId, methodName, property, privacyCode, param1, param2) 
			SELECT 0, PersonID, '[Profile.Import].[LoadProfilesData]', null, null, 'Person Insert', null FROM @newPersonIDTable
						-- add personid to user
            UPDATE  u
            SET     u.personid = p.personid
            FROM    [Profile.Data].Person p
                    JOIN [User.Account].[User] u ON u.userid = p.userid


					-- person affiliation
            INSERT  INTO [Profile.Data].[Person.Affiliation]
                    ( PersonID ,
                      SortOrder ,
                      IsActive ,
                      IsPrimary ,
                      InstitutionID ,
                      DepartmentID ,
                      DivisionID ,
                      Title ,
                      EmailAddress ,
                      FacultyRankID
					        
                    )
                    SELECT  p.personid ,
                            affiliationorder ,
                            1 ,
                            primaryaffiliation ,
                            InstitutionID ,
                            DepartmentID ,
                            DivisionID ,
                            c.title ,
                            c.emailaddr ,
                            fr.facultyrankid
                    FROM    [Profile.Import].PersonAffiliation c
                            JOIN [Profile.Data].Person p ON c.internalusername = p.internalusername
                            LEFT JOIN [Profile.Data].[Organization.Institution] i ON i.institutionname = c.institutionname
                            LEFT JOIN [Profile.Data].[Organization.Department] d ON d.departmentname = c.departmentname
                            LEFT JOIN [Profile.Data].[Organization.Division] di ON di.divisionname = c.divisionname
                            LEFT JOIN [Profile.Data].[Person.FacultyRank] fr ON fr.facultyrank = c.facultyrank
                    WHERE   NOT EXISTS ( SELECT *
                                         FROM   [Profile.Data].[Person.Affiliation] a
                                         WHERE  a.personid = p.personid
                                                AND ISNULL(a.InstitutionID, '') = ISNULL(i.InstitutionID,
                                                              '')
                                                AND ISNULL(a.DepartmentID, '') = ISNULL(d.DepartmentID,
                                                              '')
                                                AND ISNULL(a.DivisionID, '') = ISNULL(di.DivisionID,
                                                              '') )


					-- person_filters
            INSERT  INTO [Profile.Data].[Person.Filter]
                    ( PersonFilter 
					        
                    )
                    SELECT DISTINCT
                            personfilter
                    FROM    [Profile.Import].PersonFilterFlag b
                    WHERE   NOT EXISTS ( SELECT *
                                         FROM   [Profile.Data].[Person.Filter] a
                                         WHERE  a.personfilter = b.personfilter )


				-- person_filter_relationships
            INSERT  INTO [Profile.Data].[Person.FilterRelationship]
                    ( PersonID ,
                      PersonFilterid
					        
                    )
                    SELECT DISTINCT
                            p.personid ,
                            personfilterid
                    FROM    [Profile.Import].PersonFilterFlag ptf
                            JOIN [Profile.Data].[Person.Filter] pt ON pt.personfilter = ptf.personfilter
                            JOIN [Profile.Data].Person p ON p.internalusername = ptf.internalusername
                    WHERE   NOT EXISTS ( SELECT *
                                         FROM   [Profile.Data].[Person.FilterRelationship] ptf
                                                JOIN [Profile.Data].[Person.Filter] pt2 ON pt2.personfilterid = ptf.personfilterid
                                                JOIN [Profile.Data].Person p2 ON p2.personid = ptf.personid
                                         WHERE  ( p2.personid = p.personid
                                                  AND pt.personfilterid = pt2.personfilterid
                                                ) )												     										     

			-- update changed affiliation in person table
            UPDATE  p
            SET     facultyrankid = a.facultyrankid
            FROM    [Profile.Data].person p
                    OUTER APPLY ( SELECT TOP 1
                                            internalusername ,
                                            facultyrankid ,
                                            facultyranksort
                                  FROM      [Profile.import].[PersonAffiliation] pa
                                            JOIN [Profile.Data].[Person.FacultyRank] fr ON fr.facultyrank = pa.facultyrank
                                  WHERE     pa.internalusername = p.internalusername
                                  ORDER BY  facultyranksort ASC
                                ) a
            WHERE   p.facultyrankid <> a.facultyrankid
			 
			 
			-- Hide/Show Departments
            UPDATE  d
            SET     d.visible = ISNULL(t.v, 0)
            FROM    [Profile.Data].[Organization.Department] d
                    LEFT OUTER JOIN ( SELECT    a.departmentname ,
                                                MAX(CAST(a.departmentvisible AS INT)) v
                                      FROM      [Profile.Import].PersonAffiliation a ,
                                                [Profile.Import].Person p
                                      WHERE     a.internalusername = p.internalusername
                                                AND p.isactive = 1
                                      GROUP BY  a.departmentname
                                    ) t ON d.departmentname = t.departmentname


			-- Apply person active changes to user table
			UPDATE u 
			   SET isactive  = p.isactive
			  FROM [User.Account].[User] u 
			  JOIN [Profile.Data].Person p ON p.PersonID = u.PersonID 
			  
            COMMIT
        END TRY
        BEGIN CATCH
			--Check success
            IF @@TRANCOUNT > 0 
                ROLLBACK

			-- Raise an error with the details of the exception
            SELECT  @ErrMsg = ERROR_MESSAGE() ,
                    @ErrSeverity = ERROR_SEVERITY()

            RAISERROR(@ErrMsg, @ErrSeverity, 1)
        END CATCH	

    END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [Profile.Data].[Funding.GetPersonInfoForDisambiguation] 
	@startRow INT = 0,
	@nextRow INT OUTPUT
AS
BEGIN
SET nocount  ON;
 
 
	DECLARE  @search XML,
				@batchcount INT,
				@baseURI NVARCHAR(max),
				@orcidNodeID NVARCHAR(max),
				@rows INT,
				@batchSize INT

				
	SELECT @batchSize = 1000

	SELECT @baseURI = [Value] FROM [Framework.].[Parameter] WHERE [ParameterID] = 'baseURI'
	SELECT @orcidNodeID = NodeID from [RDF.].Node where Value = 'http://vivoweb.org/ontology/core#orcidId'
	
	SELECT personID, ROW_NUMBER() OVER (ORDER BY personID) AS rownum INTO #personIDs FROM [Profile.Data].Person 
	WHERE IsActive = 1

	SELECT @rows = count(*) FROM #personIDs
	SELECT @nextRow = CASE WHEN @rows > @startRow + @batchSize THEN @startRow + @batchSize ELSE -1 END

	SELECT (
		select p2.personid as PersonID, 
		ISNULL(RTRIM(firstname),'')  "Name/First",
		ISNULL(RTRIM(middlename),'') "Name/Middle",
		ISNULL(RTRIM(p2.lastname),'') "Name/Last",
		ISNULL(RTRIM(suffix),'')     "Name/Suffix",
		d.cnt "LocalDuplicateNames",
		(SELECT DISTINCT ISNULL(LTRIM(ISNULL(emailaddress,p2.emailaddr)),'') Email
				FROM [Profile.Data].[Person.Affiliation] pa
				WHERE pa.personid = p2.personid
			FOR XML PATH(''),TYPE) AS "EmailList",
		(SELECT distinct Organization as Org FROM [Profile.Data].[Funding.DisambiguationOrganizationMapping] m
			JOIN [Profile.Data].[Person.Affiliation] pa
			on m.InstitutionID = pa.InstitutionID 
				or m.InstitutionID is null
			where pa.PersonID = p2.PersonID
			FOR XML PATH(''),ROOT('OrgList'),TYPE),
		(SELECT PMID
				FROM [Profile.Data].[Publication.Person.Add]
				WHERE personid =p2.personid
			FOR XML PATH(''),ROOT('PMIDAddList'),TYPE),
		(SELECT PMID
			FROM [Profile.Data].[Publication.Person.Include]
				WHERE personid =p2.personid
			FOR XML PATH(''),ROOT('PMIDIncludeList'),TYPE),
		(SELECT PMID
			FROM [Profile.Data].[Publication.Person.Exclude]
				WHERE personid =p2.personid
			FOR XML PATH(''),ROOT('PMIDExcludeList'),TYPE),
		(SELECT FundingID FROM [Profile.Data].[Funding.Add] ad
			join [Profile.Data].[Funding.Agreement] ag
				on ad.FundingAgreementID = ag.FundingAgreementID
				and ag.Source = 'NIH'
				WHERE ad.PersonID = p2.PersonID
			FOR XML PATH(''),ROOT('GrantsAddList'),TYPE),
		(SELECT FundingID FROM [Profile.Data].[Funding.Add] ad
			join [Profile.Data].[Funding.Agreement] ag
				on ad.FundingAgreementID = ag.FundingAgreementID
				and ag.Source = 'NIH'
				WHERE ad.PersonID = p2.PersonID
			FOR XML PATH(''),ROOT('GrantsAddList'),TYPE),
		(SELECT FundingID FROM [Profile.Data].[Funding.Delete]
				WHERE Source = 'NIH' and PersonID = p2.PersonID
			FOR XML PATH(''),ROOT('GrantsDeleteList'),TYPE),
		(SELECT @baseURI + CAST(i.NodeID AS VARCHAR) 
			FOR XML PATH(''),ROOT('URI'),TYPE),
				(select n.Value as '*' from [RDF.].Node n join
				[RDF.].Triple t  on n.NodeID = t.Object
				and t.Subject = i.NodeID
				and t.Predicate = @orcidNodeID
			FOR XML PATH(''),ROOT('ORCID'),TYPE)
	FROM [Profile.Data].Person p2 
	  LEFT JOIN ( SELECT [Utility.NLP].[fnNamePart1](firstname)F,
			lastname,
			COUNT(*)cnt
			FROM [Profile.Data].Person 
			GROUP BY [Utility.NLP].[fnNamePart1](firstname), 
				lastname
			)d ON d.f = [Utility.NLP].[fnNamePart1](p2.firstname)
				AND d.lastname = p2.lastname
				AND p2.IsActive = 1 
		LEFT JOIN [RDF.Stage].[InternalNodeMap] i
			ON [InternalType] = 'Person' AND [Class] = 'http://xmlns.com/foaf/0.1/Person' AND [InternalID] = CAST(p2.personid AS VARCHAR(50))
			JOIN #personIDs p3 on p2.personID = p3.personID AND p3.rownum > @startRow and (@nextRow = -1 OR p3.rownum <= @nextRow)
	  for xml path('Person'), root('FindFunding'), type) as X
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [Profile.Data].[Publication.Pubmed.ParseALLPubMedXML]
AS
BEGIN
	SET NOCOUNT ON;

/*
	UPDATE [Profile.Data].[Publication.PubMed.AllXML] set ParseDT = GetDate() where pmid = @pmid


	delete from [Profile.Data].[Publication.PubMed.Author] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Investigator] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.PubType] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Chemical] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Databank] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Accession] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Keyword] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Grant] where pmid = @pmid
	delete from [Profile.Data].[Publication.PubMed.Mesh] where pmid = @pmid
	*/
	
	--*** general ***
	truncate table [Profile.Data].[Publication.PubMed.General.Stage]
	insert into [Profile.Data].[Publication.PubMed.General.Stage] (pmid, Owner, Status, PubModel, Volume, Issue, MedlineDate, JournalYear, JournalMonth, JournalDay, JournalTitle, ISOAbbreviation, MedlineTA, ArticleTitle, MedlinePgn, AbstractText, ArticleDateType, ArticleYear, ArticleMonth, ArticleDay, Affiliation, AuthorListCompleteYN, GrantListCompleteYN,PMCID)
		select pmid, 
			nref.value('@Owner[1]','varchar(max)') Owner,
			nref.value('@Status[1]','varchar(max)') Status,
			nref.value('Article[1]/@PubModel','varchar(max)') PubModel,
			nref.value('Article[1]/Journal[1]/JournalIssue[1]/Volume[1]','varchar(max)') Volume,
			nref.value('Article[1]/Journal[1]/JournalIssue[1]/Issue[1]','varchar(max)') Issue,
			nref.value('Article[1]/Journal[1]/JournalIssue[1]/PubDate[1]/MedlineDate[1]','varchar(max)') MedlineDate,
			nref.value('Article[1]/Journal[1]/JournalIssue[1]/PubDate[1]/Year[1]','varchar(max)') JournalYear,
			nref.value('Article[1]/Journal[1]/JournalIssue[1]/PubDate[1]/Month[1]','varchar(max)') JournalMonth,
			nref.value('Article[1]/Journal[1]/JournalIssue[1]/PubDate[1]/Day[1]','varchar(max)') JournalDay,
			nref.value('Article[1]/Journal[1]/Title[1]','varchar(max)') JournalTitle,
			nref.value('Article[1]/Journal[1]/ISOAbbreviation[1]','varchar(max)') ISOAbbreviation,
			nref.value('MedlineJournalInfo[1]/MedlineTA[1]','varchar(max)') MedlineTA,
			nref.value('Article[1]/ArticleTitle[1]','varchar(max)') ArticleTitle,
			nref.value('Article[1]/Pagination[1]/MedlinePgn[1]','varchar(max)') MedlinePgn,
			nref.value('Article[1]/Abstract[1]/AbstractText[1]','varchar(max)') AbstractText,
			nref.value('Article[1]/ArticleDate[1]/@DateType[1]','varchar(max)') ArticleDateType,
			NULLIF(nref.value('Article[1]/ArticleDate[1]/Year[1]','varchar(max)'),'') ArticleYear,
			NULLIF(nref.value('Article[1]/ArticleDate[1]/Month[1]','varchar(max)'),'') ArticleMonth,
			NULLIF(nref.value('Article[1]/ArticleDate[1]/Day[1]','varchar(max)'),'') ArticleDay,
			Affiliation = COALESCE(nref.value('Article[1]/AuthorList[1]/Author[1]/AffiliationInfo[1]/Affiliation[1]','varchar(max)'),
				nref.value('Article[1]/AuthorList[1]/Author[1]/Affiliation[1]','varchar(max)'),
				nref.value('Article[1]/Affiliation[1]','varchar(max)')) ,
			nref.value('Article[1]/AuthorList[1]/@CompleteYN[1]','varchar(max)') AuthorListCompleteYN,
			nref.value('Article[1]/GrantList[1]/@CompleteYN[1]','varchar(max)') GrantListCompleteYN,
			PMCID=COALESCE(nref.value('(OtherID[@Source="NLM" and text()[contains(.,"PMC")]])[1]', 'varchar(max)'), nref.value('(OtherID[@Source="NLM"][1])','varchar(max)'))
		from [Profile.Data].[Publication.PubMed.AllXML] cross apply x.nodes('//MedlineCitation[1]') as R(nref)
		where ParseDT is null and x is not null

		update [Profile.Data].[Publication.PubMed.General.Stage]
		set MedlineDate = (case when right(MedlineDate,4) like '20__' then ltrim(rtrim(right(MedlineDate,4)+' '+left(MedlineDate,len(MedlineDate)-4))) else null end)
		where MedlineDate is not null and MedlineDate not like '[0-9][0-9][0-9][0-9]%'

		
		update [Profile.Data].[Publication.PubMed.General.Stage]
		set PubDate = [Profile.Data].[fnPublication.Pubmed.GetPubDate](medlinedate,journalyear,journalmonth,journalday,articleyear,articlemonth,articleday)


	--*** authors ***
	truncate table [Profile.Data].[Publication.PubMed.Author.Stage]
	insert into [Profile.Data].[Publication.PubMed.Author.Stage] (pmid, ValidYN, LastName, FirstName, ForeName, Suffix, Initials, Affiliation)
		select pmid, 
			nref.value('@ValidYN','varchar(1)') ValidYN, 
			nref.value('LastName[1]','varchar(100)') LastName, 
			nref.value('FirstName[1]','varchar(100)') FirstName,
			nref.value('ForeName[1]','varchar(100)') ForeName,
			nref.value('Suffix[1]','varchar(20)') Suffix,
			nref.value('Initials[1]','varchar(20)') Initials,
			COALESCE(nref.value('AffiliationInfo[1]/Affiliation[1]','varchar(1000)'),
				nref.value('Affiliation[1]','varchar(max)')) Affiliation
		from [Profile.Data].[Publication.PubMed.AllXML] cross apply x.nodes('//AuthorList/Author') as R(nref)
		where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		


	--*** general (authors) ***

	create table #a (pmid int primary key, authors varchar(4000))
	insert into #a(pmid,authors)
		select pmid,
			(case	when len(s) < 3990 then s
					when charindex(',',reverse(left(s,3990)))>0 then
						left(s,3990-charindex(',',reverse(left(s,3990))))+', et al'
					else left(s,3990)
					end) authors
		from (
			select pmid, substring(s,3,len(s)) s
			from (
				select pmid, isnull(cast((
					select ', '+lastname+' '+initials
					from [Profile.Data].[Publication.PubMed.Author.Stage] q
					where q.pmid = p.pmid
					order by PmPubsAuthorID
					for xml path(''), type
				) as nvarchar(max)),'') s
				from [Profile.Data].[Publication.PubMed.General.Stage] p
			) t
		) t

	--[10132 in 00:00:01]
	update g
		set g.authors = isnull(a.authors,'')
		from [Profile.Data].[Publication.PubMed.General.Stage] g, #a a
		where g.pmid = a.pmid
	update [Profile.Data].[Publication.PubMed.General.Stage]
		set authors = ''
		where authors is null
		
		
		
	--*** mesh ***
	truncate table [Profile.Data].[Publication.PubMed.Mesh.Stage]
	insert into [Profile.Data].[Publication.PubMed.Mesh.Stage] (pmid, DescriptorName, QualifierName, MajorTopicYN)
		select pmid, DescriptorName, IsNull(QualifierName,''), max(MajorTopicYN)
		from (
			select pmid, 
				nref.value('@MajorTopicYN[1]','varchar(max)') MajorTopicYN, 
				nref.value('.','varchar(max)') DescriptorName,
				null QualifierName
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//MeshHeadingList/MeshHeading/DescriptorName') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
			union all
			select pmid, 
				nref.value('@MajorTopicYN[1]','varchar(max)') MajorTopicYN, 
				nref.value('../DescriptorName[1]','varchar(max)') DescriptorName,
				nref.value('.','varchar(max)') QualifierName
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//MeshHeadingList/MeshHeading/QualifierName') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where DescriptorName is not null
		group by pmid, DescriptorName, QualifierName

		
	--******************************************************************
	--******************************************************************
	--*** Update General
	--******************************************************************
	--******************************************************************

	update g
		set 
			g.pmid=a.pmid,
			g.pmcid=a.pmcid,
			g.Owner=a.Owner,
			g.Status=a.Status,
			g.PubModel=a.PubModel,
			g.Volume=a.Volume,
			g.Issue=a.Issue,
			g.MedlineDate=a.MedlineDate,
			g.JournalYear=a.JournalYear,
			g.JournalMonth=a.JournalMonth,
			g.JournalDay=a.JournalDay,
			g.JournalTitle=a.JournalTitle,
			g.ISOAbbreviation=a.ISOAbbreviation,
			g.MedlineTA=a.MedlineTA,
			g.ArticleTitle=a.ArticleTitle,
			g.MedlinePgn=a.MedlinePgn,
			g.AbstractText=a.AbstractText,
			g.ArticleDateType=a.ArticleDateType,
			g.ArticleYear=a.ArticleYear,
			g.ArticleMonth=a.ArticleMonth,
			g.ArticleDay=a.ArticleDay,
			g.Affiliation=a.Affiliation,
			g.AuthorListCompleteYN=a.AuthorListCompleteYN,
			g.GrantListCompleteYN=a.GrantListCompleteYN,
			g.PubDate = a.PubDate,
			g.Authors = a.Authors
		from [Profile.Data].[Publication.PubMed.General] (nolock) g
			inner join [Profile.Data].[Publication.PubMed.General.Stage] a
				on g.pmid = a.pmid
				
	insert into [Profile.Data].[Publication.PubMed.General] (pmid, pmcid, Owner, Status, PubModel, Volume, Issue, MedlineDate, JournalYear, JournalMonth, JournalDay, JournalTitle, ISOAbbreviation, MedlineTA, ArticleTitle, MedlinePgn, AbstractText, ArticleDateType, ArticleYear, ArticleMonth, ArticleDay, Affiliation, AuthorListCompleteYN, GrantListCompleteYN, PubDate, Authors)
		select pmid, pmcid, Owner, Status, PubModel, Volume, Issue, MedlineDate, JournalYear, JournalMonth, JournalDay, JournalTitle, ISOAbbreviation, MedlineTA, ArticleTitle, MedlinePgn, AbstractText, ArticleDateType, ArticleYear, ArticleMonth, ArticleDay, Affiliation, AuthorListCompleteYN, GrantListCompleteYN, PubDate, Authors
			from [Profile.Data].[Publication.PubMed.General.Stage]
			where pmid not in (select pmid from [Profile.Data].[Publication.PubMed.General])
	
	
	--******************************************************************
	--******************************************************************
	--*** Update Authors
	--******************************************************************
	--******************************************************************
	
	delete from [Profile.Data].[Publication.PubMed.Author] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.Author.Stage])
	insert into [Profile.Data].[Publication.PubMed.Author] (pmid, ValidYN, LastName, FirstName, ForeName, Suffix, Initials, Affiliation)
		select pmid, ValidYN, LastName, FirstName, ForeName, Suffix, Initials, Affiliation
		from [Profile.Data].[Publication.PubMed.Author.Stage]
		order by PmPubsAuthorID

		
	--******************************************************************
	--******************************************************************
	--*** Update MeSH
	--******************************************************************
	--******************************************************************


	--*** mesh ***
	delete from [Profile.Data].[Publication.PubMed.Mesh] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	--[16593 in 00:00:11]
	insert into [Profile.Data].[Publication.PubMed.Mesh]
		select * from [Profile.Data].[Publication.PubMed.Mesh.Stage]
	--[86375 in 00:00:17]

		
		
		
	--*** investigators ***
	delete from [Profile.Data].[Publication.PubMed.Investigator] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.Investigator] (pmid, LastName, FirstName, ForeName, Suffix, Initials, Affiliation)
		select pmid, 
			nref.value('LastName[1]','varchar(max)') LastName, 
			nref.value('FirstName[1]','varchar(max)') FirstName,
			nref.value('ForeName[1]','varchar(max)') ForeName,
			nref.value('Suffix[1]','varchar(max)') Suffix,
			nref.value('Initials[1]','varchar(max)') Initials,
			COALESCE(nref.value('AffiliationInfo[1]/Affiliation[1]','varchar(max)'),
				nref.value('Affiliation[1]','varchar(max)')) Affiliation
		from [Profile.Data].[Publication.PubMed.AllXML] cross apply x.nodes('//InvestigatorList/Investigator') as R(nref)
		where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		

	--*** pubtype ***
	delete from [Profile.Data].[Publication.PubMed.PubType] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.PubType] (pmid, PublicationType)
		select * from (
			select distinct pmid, nref.value('.','varchar(max)') PublicationType
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//PublicationTypeList/PublicationType') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where PublicationType is not null


	--*** chemicals
	delete from [Profile.Data].[Publication.PubMed.Chemical] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.Chemical] (pmid, NameOfSubstance)
		select * from (
			select distinct pmid, nref.value('.','varchar(max)') NameOfSubstance
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//ChemicalList/Chemical/NameOfSubstance') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where NameOfSubstance is not null


	--*** databanks ***
	delete from [Profile.Data].[Publication.PubMed.Databank] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.Databank] (pmid, DataBankName)
		select * from (
			select distinct pmid, 
				nref.value('.','varchar(max)') DataBankName
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//DataBankList/DataBank/DataBankName') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where DataBankName is not null


	--*** accessions ***
	delete from [Profile.Data].[Publication.PubMed.Accession] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.Accession] (pmid, DataBankName, AccessionNumber)
		select * from (
			select distinct pmid, 
				nref.value('../../DataBankName[1]','varchar(max)') DataBankName,
				nref.value('.','varchar(max)') AccessionNumber
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//DataBankList/DataBank/AccessionNumberList/AccessionNumber') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where DataBankName is not null and AccessionNumber is not null


	--*** keywords ***
	delete from [Profile.Data].[Publication.PubMed.Keyword] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.Keyword] (pmid, Keyword, MajorTopicYN)
		select pmid, Keyword, max(MajorTopicYN)
		from (
			select pmid, 
				nref.value('.','varchar(max)') Keyword,
				nref.value('@MajorTopicYN','varchar(max)') MajorTopicYN
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//KeywordList/Keyword') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where Keyword is not null
		group by pmid, Keyword


	--*** grants ***
	delete from [Profile.Data].[Publication.PubMed.Grant] where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
	insert into [Profile.Data].[Publication.PubMed.Grant] (pmid, GrantID, Acronym, Agency)
		select pmid, GrantID, max(Acronym), max(Agency)
		from (
			select pmid, 
				nref.value('GrantID[1]','varchar(max)') GrantID, 
				nref.value('Acronym[1]','varchar(max)') Acronym,
				nref.value('Agency[1]','varchar(max)') Agency
			from [Profile.Data].[Publication.PubMed.AllXML]
				cross apply x.nodes('//GrantList/Grant') as R(nref)
			where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
		) t where GrantID is not null
		group by pmid, GrantID


	--******************************************************************
	--******************************************************************
	--*** Update parse date
	--******************************************************************
	--******************************************************************

	update [Profile.Data].[Publication.PubMed.AllXML] set ParseDT = GetDate() where pmid in (select pmid from [Profile.Data].[Publication.PubMed.General.Stage])
END
GO


