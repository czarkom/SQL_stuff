USE db_restore
GO

SELECT * FROM admin_db.dbo.LOG_FA
SELECT * FROM faktura
SELECT * FROM klient

GO

DROP TRIGGER block_invoice_changes
DROP TRIGGER block_client_changes

UPDATE [dbo].klient SET NIP=11111 WHERE id_klienta=1
UPDATE [dbo].klient SET nazwa='Kupa' WHERE id_klienta=1
UPDATE [dbo].faktura SET id_klienta=2 WHERE id_faktury=1
UPDATE [dbo].faktura SET anulowana=1 WHERE id_faktury=1
GO

CREATE TRIGGER [dbo].[insert_faktura_trigger]
ON faktura
AFTER INSERT
AS 
BEGIN
	INSERT INTO admin_db.dbo.LOG_FA 
	SELECT ins.numer as numer_faktury, k.NIP as nip_klienta, ins.[data], ins.anulowana from
	INSERTED ins JOIN klient k on ins.id_klienta = k.id_klienta
END

GO
------------------------------------

CREATE TRIGGER [dbo].[block_client_changes]
ON [dbo].[klient]
FOR UPDATE
AS 
BEGIN
	IF EXISTS 
	(
	 SELECT * FROM INSERTED ins
	 JOIN DELETED del on ins.id_klienta = del.id_klienta
	 WHERE ins.NIP != del.NIP
	)
	BEGIN
		ROLLBACK TRANSACTION
		RAISERROR('B£¥D! NIE MO¯ESZ EDYTOWAÆ NIPU', 11 , 1);
	END
END
GO

---------------------------------------------------

CREATE TRIGGER [dbo].[block_invoice_changes]
ON [dbo].[faktura]
FOR UPDATE
AS 
BEGIN
	IF EXISTS 
	(
	SELECT * FROM inserted ins
	JOIN deleted del on ins.id_faktury = del.id_faktury 
	WHERE ( ins.numer != del.numer OR ins.id_klienta != del.id_klienta)
	)
	BEGIN
		ROLLBACK TRANSACTION
		RAISERROR('B£¥D! NIE MO¯ESZ EDYTOWAÆ ID_KLIENTA ORAZ NUMERU FAKTURY', 11 , 1);
	END
END
GO
-- Maciej Czarkowski 292810
-- Administrowanie bazami danych Z3
/************** Tworzê now¹ bazê danych pwx_db_Z3 oraz tabele faktura, klient, pozycja na potrzeby zadania **************/
IF NOT EXISTS (SELECT d.name 
					FROM sys.databases d 
					WHERE	(d.database_id > 4)
					AND		(d.[name] = N'pwx_db_Z3')
)
BEGIN
	CREATE DATABASE pwx_db_Z3
END
GO
/****************************** Usuwanie tabel *************************/
USE pwx_db_Z3
GO 

DROP TABLE pozycje
DROP TABLE faktura
DROP TABLE klient
/******************************* Tworzê nowe tabele *********************/

-- tabela klient
USE pwx_db_Z3
GO

IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'klient')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.klient
	(	[id_klienta]		int				NOT NULL IDENTITY constraint pk_klienta primary key
	,	[NIP]				nvarchar(20)	NOT NULL
	,	[nazwa]				nvarchar(100)	NOT NULL
	,	[adres]				nvarchar(100)	NOT NULL
	)
END
GO

-- tabela faktura
USE pwx_db_Z3
GO

IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'faktura')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.faktura
	(	[id_faktury]	int			NOT NULL IDENTITY constraint pk_faktury primary key
	,	[id_klienta]	int			NOT NULL constraint pk_fk_klienta foreign key references klient(id_klienta)
	,	[data]			datetime	NOT NULL
	,	[numer]			int			NOT NULL
	,   [anulowana]		bit			NOT NULL
	)
END
GO

-- tabela pozycje

USE pwx_db_Z3
GO

IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'pozycje')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.pozycje
	(	[id_faktury]	int				NOT NULL constraint pk_fk_faktury foreign key references faktura(id_faktury)
	,	[opis]			nvarchar(100)	NOT NULL
	,	[cena]			float			NOT NULL
	)
END
GO

-------------------------------------------------------------------------------------------------------------------
/********************************************** Wstawiam dane ***************************************************/

USE pwx_db_Z3
GO

DECLARE @id_mc int , @id_td int, @id_ms int, @id_mm int, @id_kd int

INSERT INTO klient VALUES ('7876537', 'Maciej Kasztanabe', 'Tbilisi')
SET @id_mc = SCOPE_IDENTITY()

INSERT INTO klient VALUES ('1247895', 'Tomasz Duszanski', 'Kutaisi')
SET @id_td = SCOPE_IDENTITY()

INSERT INTO klient VALUES ('9214657', 'Monika Sarzoghlu', 'Moskwa')
SET @id_ms = SCOPE_IDENTITY()

INSERT INTO klient VALUES ('1265444', 'Maria Maren', 'Jakuck')
SET @id_mm = SCOPE_IDENTITY()

INSERT INTO klient VALUES ('9874698', 'Karen Daniel', 'Houston')
SET @id_kd = SCOPE_IDENTITY()

INSERT INTO faktura VALUES 
(@id_ms, convert(datetime,'20070101',112), 2005, 0),
(@id_ms, convert(datetime,'20150101',112), 2808, 0),
(@id_kd, convert(datetime,'20180101',112), 2003, 0),
(@id_td, convert(datetime,'20110101',112), 1222, 0),
(@id_td, convert(datetime,'20200301',112), 7863, 0),
(@id_ms, convert(datetime,'20200708',112), 1232, 0),
(@id_ms, convert(datetime,'20191121',112), 1234, 0),
(@id_ms, convert(datetime,'20200401',112), 5432, 0),
(@id_mm, convert(datetime,'20200114',112), 9877, 0),
(@id_kd, convert(datetime,'20210225',112), 2318, 0)

---------------------------------------------------------------------------------------------------------------------------
/*************************************************** Baza administracyjna *******************************************/
-- Tworzê bazê adminstracyjn¹
IF NOT EXISTS (SELECT d.name 
					FROM sys.databases d 
					WHERE	(d.database_id > 4)
					AND		(d.[name] = N'admin_db')
)
BEGIN
	CREATE DATABASE admin_db
END
GO

USE admin_db
GO
/** Usuwanie tabeli **/
DROP TABLE LOG_FA

-- Tworzê tabelê LOG_FA
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'LOG_FA')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.[LOG_FA]
	(	[numer_faktury]	int			not null
	,	[nip_klienta]	int			not null
	,	[data]			datetime	not null
	,	[anulowana]		bit			not null
	)
	END
GO

-------------------------------------------------------------------------------------------------------------------------
/***************************************************** Triggery *******************************************************/

USE pwx_db_Z3
GO

-- Trigger na UPDATE klienta
DROP TRIGGER [dbo].[block_client_changes]
GO

CREATE TRIGGER [dbo].[block_client_changes]
ON [dbo].[klient]
AFTER UPDATE
AS 
BEGIN
	CREATE TABLE #TT (id_klienta int, NIP int, nazwa nvarchar(100), adres nvarchar(100) )
	INSERT INTO #TT (id_klienta, NIP, nazwa, adres)
	(
		SELECT  ins.id_klienta, del.NIP, ins.nazwa, ins.adres  
		FROM inserted ins 
		LEFT JOIN deleted del ON del.id_klienta = ins.id_klienta
		WHERE del.NIP != ins.NIP
	)

	UPDATE klient
	SET NIP = tt.NIP, nazwa = tt.nazwa, adres = tt.adres
	FROM #TT tt
	WHERE tt.id_klienta = klient.id_klienta
END
GO

--test triggera
--UPDATE klient SET NIP=3456544  WHERE id_klienta=1
--SELECT * from klient

-- Trigger na UPDATE faktury
DROP TRIGGER [dbo].[block_invoice_changes]
GO

CREATE TRIGGER [dbo].[block_invoice_changes]
ON [dbo].[faktura]
AFTER UPDATE
AS 
BEGIN
	CREATE TABLE #TT (id_faktury int, id_klienta int, [data] datetime, numer int, anulowana bit )
	INSERT INTO #TT (id_faktury, id_klienta, [data], numer, anulowana)
	(
		SELECT  ins.id_faktury, del.id_klienta, ins.[data], del.numer, ins.anulowana  
		FROM inserted ins 
		LEFT JOIN deleted del ON del.id_faktury = ins.id_faktury
		WHERE (del.id_klienta != ins.id_klienta OR del.numer != ins.numer)
	)

	UPDATE faktura
	SET id_klienta = tt.id_klienta, [data] = tt.[data], numer = tt.numer, anulowana = tt.anulowana
	FROM #TT tt
	WHERE tt.id_faktury = faktura.id_faktury
END
GO

USE db_restore
GO
--test triggera
--UPDATE faktura SET numer=1111, id_klienta=1, anulowana=1  WHERE id_faktury BETWEEN 1 AND 4
--SELECT * from faktura

-- Trigger na INSERT nowej faktury/faktur (mo¿e byæ kilka na raz w jednym zapytaniu
DROP TRIGGER [dbo].[insert_faktura_trigger]
GO

CREATE TRIGGER [dbo].[insert_faktura_trigger]
ON faktura
AFTER INSERT
AS 
BEGIN
	SELECT * FROM INSERTED
	DECLARE CUR INSENSITIVE CURSOR FOR
		SELECT DISTINCT ins.id_klienta FROM INSERTED ins
			ORDER BY 1
	OPEN CUR

	DECLARE @tmp_id int
	FETCH NEXT FROM CUR INTO @tmp_id

	DECLARE @tmp_var int
	WHILE (@@FETCH_STATUS = 0)
		BEGIN
			SELECT @tmp_var = k.NIP FROM klient k INNER JOIN INSERTED ON k.id_klienta = @tmp_id

			INSERT INTO admin_db.dbo.LOG_FA (numer_faktury, nip_klienta, [data], anulowana)
				(SELECT ins.numer, @tmp_var, ins.[data], ins.anulowana FROM INSERTED ins WHERE ins.id_klienta = @tmp_id)
			FETCH NEXT FROM CUR INTO @tmp_id
		END
	CLOSE CUR
	DEALLOCATE CUR
END

GO

--test triggera (sprawdzam czy s¹ nowe rekordy w admin_db w LOG_FA po wstawieniu faktur)
USE admin_db
GO

SELECT * FROM dbo.LOG_FA

--------------------------------------------------------------------------------------------------------------------------
/************************************************* Backup bazy **********************************************************/

USE admin_db
GO

/* backup pojedynczej bazy*/
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'Z3_database_backup')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.Z3_database_backup AS '
	EXEC sp_sqlexec @stmt
END
GO

ALTER PROCEDURE dbo.Z3_database_backup
AS
BEGIN
	DECLARE @path nvarchar(1000), @fname nvarchar(256), @sql nvarchar(200), @db nvarchar(100)
	SET @db = 'pwx_db_Z3'
	SET @path = N'C:\temp\'  
	SET @db = LTRIM(RTRIM(@db))
	SET @fname = REPLACE(REPLACE(CONVERT(nchar(19), GETDATE(), 126), N':', N'_'),'-','_')
	SET @fname = @path + RTRIM(@db)  + @fname + N'.bak'
	SET @sql = 'backup database ' + @db + ' to DISK= ''' + @fname + ''''
	EXEC sp_sqlexec @sql
END
GO

EXEC dbo.Z3_database_backup

-------------------------------------------------------------------------------------------------------------------------
/********************************************* Odtworzenie bazy **********************************************************/

RESTORE DATABASE db_restore FROM DISK = N'C:\temp\pwx_db_Z32020_11_30T09_09_12.bak' WITH REPLACE

--------------------------------------------------------------------------------------------------------------------------
/*********************************************** Porównywanie ***********************************************************/

USE admin_db
GO
/******************************************************************/
-- Porównywanie loga z tabel¹ faktura w bazie podanej jako argument
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'compare_log_with_db')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.compare_log_with_db AS '
	EXEC sp_sqlexec @stmt
END
GO

ALTER PROCEDURE dbo.compare_log_with_db (@db nvarchar(100))
AS
BEGIN
	CREATE TABLE #TT ([numer_faktury] int, [nip_klienta] int, [data] datetime, [anulowana] bit )
	DECLARE @sql nvarchar(1000)
	SET @sql = 'SELECT f.numer AS numer_faktury, k.NIP AS nip_klienta, f.[data], f.anulowana FROM ' + @db + '.dbo.faktura f
	INNER JOIN ' + @db + '.dbo.klient k ON k.id_klienta = f.id_klienta'
	INSERT INTO #TT exec (@sql)
	
	SELECT * FROM admin_db.dbo.LOG_FA
	EXCEPT
	SELECT * FROM #TT 
	DROP TABLE #TT
END
GO

/******************************************************************/
-- Porównywanie loga z tabel¹ faktura w bazie podanej jako argument
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'compare_db_with_log')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.compare_db_with_log AS '
	EXEC sp_sqlexec @stmt
END
GO

ALTER PROCEDURE dbo.compare_db_with_log (@db nvarchar(100))
AS
BEGIN
	CREATE TABLE #TT ([numer_faktury] int, [nip_klienta] int, [data] datetime, [anulowana] bit )
	DECLARE @sql nvarchar(1000)
	SET @sql = 'SELECT f.numer AS numer_faktury, k.NIP AS nip_klienta, f.[data], f.anulowana FROM ' + @db + '.dbo.faktura f
	INNER JOIN ' + @db + '.dbo.klient k ON k.id_klienta = f.id_klienta'
	INSERT INTO #TT exec (@sql)
	
	SELECT * FROM #TT
	EXCEPT
	SELECT * FROM admin_db.dbo.LOG_FA
	DROP TABLE #TT
END
GO

/*******************************************/
-- Testy porównywania
EXEC dbo.compare_db_with_log @db='db_restore'
EXEC dbo.compare_log_with_db @db='db_restore'
-------------------------------------------------------------------------------------------------------------
/************************************************************************************************************/
-- Zapytania pomocnicze do testów
SELECT * FROM admin_db.dbo.LOG_FA
SELECT * FROM pwx_db_Z3.dbo.faktura