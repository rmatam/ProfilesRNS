SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [ORCID.].[PersonWorkIdentifier](
	[PersonWorkIdentifierID] [int] IDENTITY(1,1) NOT NULL,
	[PersonWorkID] [int] NOT NULL,
	[WorkExternalTypeID] [tinyint] NOT NULL,
	[Identifier] [varchar](250) NOT NULL,
 CONSTRAINT [PK_PersonWorkIdentifier] PRIMARY KEY CLUSTERED 
(
	[PersonWorkIdentifierID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [ORCID.].[PersonWorkIdentifier]  WITH CHECK ADD  CONSTRAINT [FK_PersonWorkIdentifier_PersonWork] FOREIGN KEY([PersonWorkID])
REFERENCES [ORCID.].[PersonWork] ([PersonWorkID])
GO
ALTER TABLE [ORCID.].[PersonWorkIdentifier] CHECK CONSTRAINT [FK_PersonWorkIdentifier_PersonWork]
GO
ALTER TABLE [ORCID.].[PersonWorkIdentifier]  WITH CHECK ADD  CONSTRAINT [FK_PersonWorkIdentifier_WorkExternalTypeID] FOREIGN KEY([WorkExternalTypeID])
REFERENCES [ORCID.].[REF_WorkExternalType] ([WorkExternalTypeID])
GO
ALTER TABLE [ORCID.].[PersonWorkIdentifier] CHECK CONSTRAINT [FK_PersonWorkIdentifier_WorkExternalTypeID]
GO
