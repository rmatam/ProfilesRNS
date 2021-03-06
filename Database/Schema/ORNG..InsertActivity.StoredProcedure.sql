SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [ORNG.].[InsertActivity](@Uri nvarchar(255),@AppID INT, @ActivityID int, @Activity XML)
As
BEGIN
	SET NOCOUNT ON
	DECLARE @NodeID bigint
	
	select @NodeID = [RDF.].[fnURI2NodeID](@Uri);	
	IF (@ActivityID IS NULL OR @ActivityID < 0)
		INSERT [ORNG.].[Activity] (NodeID, AppID, Activity) values (@NodeID, @AppID, @Activity)
	ELSE 		
		INSERT [ORNG.].[Activity] (ActivityID, NodeID, AppID, Activity) values (@ActivityID, @NodeID, @AppID, @Activity)
END		

GO
