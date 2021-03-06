SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [RDF.SemWeb].[vwHash2Base64]
	AS
	SELECT NodeID, SemWebHash
		FROM [RDF.SemWeb].[Hash2Base64]

	/*

	-- This version of the view allows truncation / modification to [RDF.].Node	
	AS
	SELECT NodeID, [RDF.SemWeb].[fnHash2Base64](ValueHash) SemWebHash
		FROM [RDF.].Node

	-- This version of the view allows indexes
	WITH SCHEMABINDING
	AS
	SELECT NodeID, [RDF.SemWeb].[fnHash2Base64](ValueHash) SemWebHash
		FROM [RDF.].Node
	
	--Run after creating this view
	CREATE UNIQUE CLUSTERED INDEX [idx_SemWebHash] ON [RDF.SemWeb].[vwHash2Base64]([SemWebHash] ASC)
	CREATE UNIQUE NONCLUSTERED INDEX [idx_NodeID] ON [RDF.SemWeb].[vwHash2Base64]([NodeID] ASC)

	*/

GO
