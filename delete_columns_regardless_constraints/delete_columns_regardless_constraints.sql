/************************* Z5 Maciej Czarkowski 292810 ***********************************/
USE z4_baza
GO
/*********************** Procedura do usuwania ********************/
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'delete_column')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.delete_column AS '
	EXEC sp_sqlexec @stmt
END
GO

ALTER PROCEDURE dbo.delete_column (@db nvarchar(100), @table nvarchar(100), @column nvarchar(100))
AS
BEGIN
	DECLARE @sql nvarchar(1000), @constraint nvarchar(256)
	CREATE TABLE #FK ([constraint_name] varchar(30))
	CREATE TABLE #CHECK ([column_name] varchar(30))

	-- Sprawdzam czy kolumna istnieje w danej tabeli
	SET @sql = N'USE [' + @db + N']; '
	+ 'INSERT INTO #CHECK '
	+ 'SELECT 1 FROM sys.columns sc JOIN sys.objects so ON sc.object_id=so.object_id'
	+ ' WHERE sc.name=''' + @column +''' AND so.name=''' + @table + ''''
	--SELECT @sql
	EXEC sp_sqlexec @sql
	IF NOT EXISTS 
	(
		SELECT 1 FROM #CHECK
	)
	BEGIN
		RAISERROR('B£¥D! NIE MA TAKIEJ KOLUMNY', 11 , 1);
		RETURN -1
	END

	-- Sprawdzam jakie ograniczenia bêd¹ do zdjêcia
	SET @sql = N'USE [' + @db + N']; '
	+ 'INSERT INTO #FK '
	+ 'SELECT so.name FROM sys.objects so '
	+ 'JOIN sys.columns sc ON so.parent_object_id=sc.object_id '
	+ 'JOIN sys.tables st ON st.object_id=sc.object_id '
	+ 'WHERE sc.name=''' + @column +''' AND st.name=''' + @table + ''''

	--SELECT @sql
	EXEC sp_sqlexec @sql
	--SELECT * FROM #FK

	DECLARE CC INSENSITIVE CURSOR FOR 
			SELECT *
				FROM #FK f
				ORDER BY 1
	OPEN CC
	FETCH NEXT FROM CC INTO @constraint

	-- W pêtli zdejmuje ograniczenia
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @sql = 'USE [' + @db + N']; '
		+ N'ALTER TABLE ' + @table + N' DROP CONSTRAINT ' + @constraint
		EXEC sp_sqlexec @sql
		FETCH NEXT FROM CC INTO @constraint
	END
	CLOSE CC
	DEALLOCATE CC

	-- Po usuniêciu ograniczeñ usuwam kolumnê
	SET @sql = 'USE [' + @db + N']; '
		+ N'ALTER TABLE ' + @table + N' DROP COLUMN ' + @column
	EXEC sp_sqlexec @sql
END
GO

/******************* Zapytania testowe *********************/
SELECT * FROM sys.columns

DROP TABLE test_us_kol

CREATE TABLE test_us_kol ([id] nchar(6), czy_wazny bit NOT NULL default 0)
go
/* próbujê usun¹æ czy_wazny z tabeli 
*/
ALTER TABLE test_us_kol drop column czy_wazny

SELECT * FROM test_us_kol
/****************** Test procedury *****************************/
EXEC dbo.delete_column @db = 'z4_baza', @table = 'test_us_kol', @column = 'czy_wazny';
/***************************************************************/