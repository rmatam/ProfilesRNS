SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [ORNG.].[Messages](
	[MsgID] [nvarchar](255) NOT NULL,
	[SenderNodeID] [bigint] NULL,
	[RecipientNodeID] [bigint] NULL,
	[Coll] [nvarchar](255) NULL,
	[Title] [nvarchar](255) NULL,
	[Body] [nvarchar](4000) NULL,
	[CreatedDT] [datetime] NULL
) ON [PRIMARY]

GO
ALTER TABLE [ORNG.].[Messages] ADD  CONSTRAINT [DF_orng_messages_createdDT]  DEFAULT (getdate()) FOR [CreatedDT]
GO
