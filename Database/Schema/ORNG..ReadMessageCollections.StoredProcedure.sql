SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [ORNG.].[ReadMessageCollections](@RecipientUri nvarchar(255))
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @RecipientNodeID bigint
	
	select @RecipientNodeID = [RDF.].[fnURI2NodeID](@RecipientUri)

	SELECT DISTINCT Coll	FROM [ORNG.].[Messages] WHERE RecipientNodeID =  @RecipientNodeID
END

GO
