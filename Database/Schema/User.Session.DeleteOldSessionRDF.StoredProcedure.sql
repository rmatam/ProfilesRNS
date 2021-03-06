SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [User.Session].[DeleteOldSessionRDF]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Get a list of nodes for sessions last used more than 7 days ago
	CREATE TABLE #s (
		NodeID BIGINT PRIMARY KEY
	)
	INSERT INTO #s (NodeID)
		SELECT DISTINCT NodeID
			FROM (
				SELECT TOP 1000000 NodeID
					FROM [User.Session].[Session] WITH (NOLOCK)
					WHERE NodeID IS NOT NULL
						AND NodeID IN (SELECT NodeID FROM [RDF.].[Node] WITH (NOLOCK))
						AND DateDiff(dd,LastUsedDate,GetDate()) >= 7
			) t

	-- Get a list of the triples associated with those nodes
	CREATE TABLE #t (
		TripleID BIGINT PRIMARY KEY
	)
	INSERT INTO #t (TripleID)
		SELECT t.TripleID
			FROM [RDF.].[Triple] t WITH (NOLOCK), #s s
			WHERE t.subject = s.NodeID

	-- Delete the triples
	DELETE t
		FROM [RDF.].[Triple] t, #t s
		WHERE t.TripleID = s.TripleID

	-- Turn off real-time indexing
	--ALTER FULLTEXT INDEX ON [RDF.].Node SET CHANGE_TRACKING OFF 
	
	-- Delete the nodes
	DELETE n
		FROM [RDF.].[Node] n, #s s
		WHERE n.NodeID = s.NodeID

	-- Turn on real-time indexing
	--ALTER FULLTEXT INDEX ON [RDF.].Node SET CHANGE_TRACKING AUTO;
	-- Kick off population FT Catalog and index
	--ALTER FULLTEXT INDEX ON [RDF.].Node START FULL POPULATION 


	/*

	SELECT *
		FROM [User.Session].[Session] WITH (NOLOCK)
		WHERE NodeID IS NOT NULL
			AND NodeID IN (SELECT NodeID FROM [RDF.].[Node] WITH (NOLOCK))
			AND DateDiff(hh,LastUsedDate,GetDate()) >= 24
			--AND ((LogoutDate IS NOT NULL) OR (DateDiff(hh,LastUsedDate,GetDate()) >= 24))

	SELECT *
		FROM [RDF.].[Triple] t, #s s
		WHERE t.subject = s.NodeID

	SELECT *
		FROM [RDF.].[Node] n, #s s
		WHERE n.NodeID = s.NodeID

	*/

END

GO
