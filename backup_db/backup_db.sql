USE DB_STAT
GO

/* Z2 
** Napisac 2 procedury
** bk_db - backup pojedynczej bazy
** bk_all_db - backup wszystkich baz
** do pliku na wyznaczonym katalogu
** nazwa kazdego pliku to nazwabazy PODKRESLENIE YYYYYMMDDHHMM
** Zaplanowaæ uruchamianie procedury backupy wszystkich baz poprzez SQL Agent na co dzien
** Zdokumentowac i udowodnic, ze JOB zadziala³ i pliki powsta³y
*/

/* wskazówka -> s³adnia backupu do pliku 
*/

DECLARE @db nvarchar(100) -- to bedzie parametr procedury
, @path nvarchar(200) -- drugi parametr np domyslnie C:\temp\ musi sie konczyc na \
						-- jak sie nie konczy to dodajemy
, @fname nvarchar(1000)

/* normalnie to bed¹ parametry wywolania - sprawdzamy czy baza istnieje */

SET @db = N'PWX_DB'
SET @path = N'C:\temp\'  

SET @fname = REPLACE(REPLACE(CONVERT(nchar(19), GETDATE(), 126), N':', N'_'),'-','_')
SET @fname = @path + RTRIM(@db)  + @fname + N'.bak'

-- test
-- SELECT @fname
-- C:\temp\PWX_DB2020_10_29T15_13_50.bak

DECLARE @sql nvarchar(100)

SET @sql = 'backup database ' + @db + ' to DISK= ''' + @fname + ''''
--backup database PWX_DB to DISK= 'C_\temp\PWX_DB2020_10_29T15_12_43.bak'
-- test
-- SELECT @sql
-- backup database PWX_DB to DISK= 'C:\temp\PWX_DB2020_10_29T15_14_29.bak'

EXEC sp_sqlexec @sql
---------------------------------------------------------------------------------------------------------------------
/* backup pojedynczej bazy*/
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'BK_DB')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.BK_DB AS '
	EXEC sp_sqlexec @stmt
END
GO

USE DB_STAT
GO

ALTER PROCEDURE dbo.BK_DB @db nvarchar(100), @commt nvarchar(20) = 'database_backup'
AS
	DECLARE @path nvarchar(1000), @fname nvarchar(256), @sql nvarchar(200)
	SET @path = N'C:\temp\'  
	SET @db = LTRIM(RTRIM(@db)) -- usuwamy spacje pocz¹tkowe i koncowe z nazwy bazy
	SET @fname = REPLACE(REPLACE(CONVERT(nchar(19), GETDATE(), 126), N':', N'_'),'-','_')
	SET @fname = @path + RTRIM(@db)  + @fname + N'.bak'
	SET @sql = 'backup database ' + @db + ' to DISK= ''' + @fname + ''''
	EXEC sp_sqlexec @sql
	INSERT INTO DB_STAT.dbo.DB_STAT (comment, db_nam) VALUES (@commt, @db)
GO

-------------------------------------------------------
/*test procedury*/
EXEC dbo.BK_DB  @db='pwx_db'
---------------------------------------------------------------------------------------------------------------------------------
/* backup wszystkich baz*/
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'BK_ALL_DB')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.BK_ALL_DB AS '
	EXEC sp_sqlexec @stmt
END
GO

USE DB_STAT
GO

ALTER PROCEDURE dbo.BK_ALL_DB
AS
	DECLARE @sql nvarchar(1000)

	DECLARE CCA INSENSITIVE CURSOR FOR
			SELECT d.name 
			FROM sys.databases d 
			WHERE d.database_id > 4 -- ponizej 5 s¹ systemowe
	DECLARE @db nvarchar(100)
	OPEN CCA
	FETCH NEXT FROM CCA INTO @db

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC DB_STAT.dbo.BK_DB @db = @db, @commt = 'all_database_backup'
		FETCH NEXT FROM CCA INTO @db
	END
	CLOSE CCA
	DEALLOCATE CCA
	
GO

---------------------------------------------
/* Test procedury do tworzenia backupu wszystkich baz */
EXEC dbo.BK_ALL_DB