SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [ORCID.].[Person](
	[PersonID] [int] IDENTITY(1,1) NOT NULL,
	[InternalUsername] [nvarchar](100) NOT NULL,
	[PersonStatusTypeID] [tinyint] NOT NULL,
	[CreateUnlessOptOut] [bit] NOT NULL,
	[ORCID] [varchar](50) NULL,
	[ORCIDRecorded] [smalldatetime] NULL,
	[FirstName] [nvarchar](150) NULL,
	[LastName] [nvarchar](150) NULL,
	[PublishedName] [nvarchar](500) NULL,
	[EmailDecisionID] [tinyint] NULL,
	[EmailAddress] [varchar](300) NULL,
	[AlternateEmailDecisionID] [tinyint] NULL,
	[AgreementAcknowledged] [bit] NULL,
	[Biography] [varchar](5000) NULL,
	[BiographyDecisionID] [tinyint] NULL,
 CONSTRAINT [PK_Person] PRIMARY KEY CLUSTERED 
(
	[PersonID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [ORCID.].[Person]  WITH CHECK ADD  CONSTRAINT [fk_Person_AlternateEmailDecisionID] FOREIGN KEY([AlternateEmailDecisionID])
REFERENCES [ORCID.].[REF_Decision] ([DecisionID])
GO
ALTER TABLE [ORCID.].[Person] CHECK CONSTRAINT [fk_Person_AlternateEmailDecisionID]
GO
ALTER TABLE [ORCID.].[Person]  WITH CHECK ADD  CONSTRAINT [fk_Person_BiographyDecisionID] FOREIGN KEY([BiographyDecisionID])
REFERENCES [ORCID.].[REF_Decision] ([DecisionID])
GO
ALTER TABLE [ORCID.].[Person] CHECK CONSTRAINT [fk_Person_BiographyDecisionID]
GO
ALTER TABLE [ORCID.].[Person]  WITH CHECK ADD  CONSTRAINT [fk_Person_EmailDecisionID] FOREIGN KEY([EmailDecisionID])
REFERENCES [ORCID.].[REF_Decision] ([DecisionID])
GO
ALTER TABLE [ORCID.].[Person] CHECK CONSTRAINT [fk_Person_EmailDecisionID]
GO
ALTER TABLE [ORCID.].[Person]  WITH CHECK ADD  CONSTRAINT [fk_Person_personstatustypeid] FOREIGN KEY([PersonStatusTypeID])
REFERENCES [ORCID.].[REF_PersonStatusType] ([PersonStatusTypeID])
GO
ALTER TABLE [ORCID.].[Person] CHECK CONSTRAINT [fk_Person_personstatustypeid]
GO
