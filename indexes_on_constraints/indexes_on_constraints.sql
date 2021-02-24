/************************* Z4 Maciej Czarkowski 292810 ***********************************/
USE z4_baza
GO
/******************************************************************/
-- Dodanie indeksów dla nieistniej¹cych kluczy obcych
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'create_missing_indexes')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.create_missing_indexes AS '
	EXEC sp_sqlexec @stmt
END
GO

ALTER PROCEDURE dbo.create_missing_indexes (@db nvarchar(100))
AS
BEGIN
	DECLARE @sql nvarchar(1000), @table nvarchar(256), @column nvarchar(256), @fk nvarchar(256)

	CREATE TABLE #FK ([fk_name] varchar(30), [object_id] int, [table_name] varchar(30), [column_name] varchar(30))
	SET @sql = N'USE [' + @db + N']; '
			+ N'INSERT INTO #FK
				SELECT f.name, 
				f.[object_id],
				OBJECT_NAME(f.parent_object_id) referencing_table_name, 
				COL_NAME(fc.parent_object_id, fc.parent_column_id) referencing_column_name
				FROM sys.foreign_keys f
				JOIN sys.foreign_key_columns AS fc
				ON f.[object_id] = fc.constraint_object_id'

	EXEC sp_sqlexec @sql
	
	CREATE TABLE #IndexedFK ([object_id] int)
	INSERT INTO #IndexedFK
	SELECT fc.[constraint_object_id]
	FROM sys.foreign_key_columns fc
	JOIN sys.index_columns ic ON fc.[parent_object_id] = ic.[object_id]
	JOIN #FK fk ON fc.constraint_object_id = fk.[object_id]
	WHERE fc.parent_column_id = ic.column_id

	CREATE TABLE #IndexesToAdd([fk_name] varchar(30), [object_id] int, [table_name] varchar(30), [column_name] varchar(30))
	
	INSERT INTO #IndexesToAdd 
	SELECT * FROM #FK f WHERE f.[object_id] NOT IN (SELECT object_id FROM #IndexedFK)

	DECLARE CC INSENSITIVE CURSOR FOR 
			SELECT o.[fk_name], o.[table_name], o.[column_name]
				FROM #IndexesToAdd o
				ORDER BY 1

	OPEN CC
	FETCH NEXT FROM CC INTO @fk, @table, @column
	
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @sql = 'USE [' + @db + N']; '
		+ N'CREATE INDEX i' + @fk + N' ON ' + @table + N' (' + @column + N')'
		EXEC sp_sqlexec @sql
	
		FETCH NEXT FROM CC INTO @fk, @table, @column
	END
	CLOSE CC
	DEALLOCATE CC
END
GO

EXEC dbo.create_missing_indexes 'z4_baza'

CREATE INDEX ifk_miasta__woj ON miasta (kod_woj)
SELECT * FROM sys.indexes WHERE name LIKE 'ifk%'
SELECT * FROM sys.sysconstraints
SELECT * FROM osoby o WITH(Index(ifk_osoby__miasta))
JOIN miasta m ON (o.id_miasta=m.id_miasta)