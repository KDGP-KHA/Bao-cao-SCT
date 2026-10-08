/*
Run in the SysProvider database containing dbo.Sys_Users.
Category database below follows the existing report scripts; adjust for your environment.
Start with @Apply = 0 to review the affected accounts, then set it to 1 to apply.

Registration uses TaxCode as UserName (AccountController.Register). Only matching
enterprise accounts are targeted; other accounts are left alone. TaxCodes with
fewer than six ASCII digits are skipped, with no padding or numeric conversion.

New password: RIGHT(strip non-digits from TaxCode, 6) + '@SCT'.
New seed (Salt): a fresh Base64-encoded 32-byte random value per account.
Password: uppercase SHA1 of UTF8(password + Salt), matching
UPasswordHash.GenerateCryptoPassword in TSFramework.Core/Utils/EPasswordHash.cs.
All hash input characters here are ASCII, so varchar bytes equal UTF8 bytes.
SysUserBiz.ResetPassword calls p_Sys_User_ResetPassword with these five inputs:
UserName, Password hash, Salt, Reason, ChangeBy. Use reset because old passwords
are unknown. The procedure body is not included in the repository; deployment
checks its input signature and verifies the stored hash/salt after each call.

This deliberately reproduces the application's existing password format.
Plaintext passwords and salts are not printed. Existing login sessions/cache
are not invalidated by SQL; coordinate application session/cache refresh.
Each applied run generates fresh salts and resets the matching accounts again.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply bit = 0;
DECLARE @Reason nvarchar(500) = N'Migrate enterprise passwords to TaxCode suffix + @SCT';
DECLARE @ChangeBy nvarchar(256) = N'Sys_Users password migration';

IF @@TRANCOUNT <> 0
    THROW 50001, 'Run this migration outside an existing transaction.', 1;
IF OBJECT_ID(N'dbo.Sys_Users', N'U') IS NULL
    THROW 50002, 'Select the SysProvider database containing dbo.Sys_Users.', 1;
IF OBJECT_ID(N'dbo.p_Sys_User_ResetPassword', N'P') IS NULL
    THROW 50003, 'Missing dbo.p_Sys_User_ResetPassword.', 1;
IF (SELECT COUNT(*) FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.p_Sys_User_ResetPassword')
      AND parameter_id > 0) <> 5
    THROW 50004, 'Inspect reset procedure signature: expected five positional inputs from SysUserBiz.', 1;

SELECT DISTINCT u.UserId, u.UserName, CONVERT(nvarchar(max), e.TaxCode) AS TaxCode,
       CAST(N'' AS nvarchar(max)) AS Digits
INTO #Targets
FROM dbo.Sys_Users AS u
INNER JOIN [baocao.sct.cenit.vn.cate].dbo.Cate_Enterprises AS e
    ON e.TaxCode COLLATE DATABASE_DEFAULT = u.UserName COLLATE DATABASE_DEFAULT;

-- Remove every non-ASCII-digit, retaining leading zeroes and branch suffixes.
WHILE EXISTS (SELECT 1 FROM #Targets
              WHERE PATINDEX(N'%[^0-9]%', TaxCode COLLATE Latin1_General_100_BIN2) > 0)
BEGIN
    UPDATE #Targets
    SET TaxCode = STUFF(TaxCode,
        PATINDEX(N'%[^0-9]%', TaxCode COLLATE Latin1_General_100_BIN2), 1, N'')
    WHERE PATINDEX(N'%[^0-9]%', TaxCode COLLATE Latin1_General_100_BIN2) > 0;
END;
UPDATE #Targets SET Digits = TaxCode;

SELECT UserId, UserName,
       CASE WHEN LEN(Digits) >= 6 THEN 'Will reset' ELSE 'Skipped: fewer than six digits' END AS MigrationStatus
FROM #Targets ORDER BY UserId;

DELETE FROM #Targets WHERE LEN(Digits) < 6;
IF EXISTS (SELECT UserId FROM #Targets GROUP BY UserId HAVING COUNT(*) > 1)
    THROW 50005, 'Ambiguous enterprise TaxCode mapping for a user.', 1;

IF @Apply = 0
BEGIN
    SELECT COUNT(*) AS EligibleAccounts, 'Preview only; set @Apply = 1 to execute.' AS Result
    FROM #Targets;
    DROP TABLE #Targets;
    RETURN;
END;

DECLARE @UserId int, @UserName nvarchar(256), @Digits nvarchar(max);
DECLARE @Password varchar(10), @Salt varchar(44), @Hash varchar(40);
DECLARE @SaltBytes varbinary(32), @Byte varbinary(1), @Updated int = 0;
DECLARE UsersToReset CURSOR LOCAL FAST_FORWARD FOR
    SELECT UserId, UserName, Digits FROM #Targets ORDER BY UserId;

BEGIN TRY
    BEGIN TRANSACTION;
    OPEN UsersToReset;
    FETCH NEXT FROM UsersToReset INTO @UserId, @UserName, @Digits;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Password = CONVERT(varchar(6), RIGHT(@Digits, 6)) + '@SCT';
        -- GenerateSalt(32) uses GetNonZeroBytes; match that distribution.
        SET @SaltBytes = 0x;
        WHILE DATALENGTH(@SaltBytes) < 32
        BEGIN
            SET @Byte = CRYPT_GEN_RANDOM(1);
            IF @Byte <> 0x00 SET @SaltBytes = @SaltBytes + @Byte;
        END;
        SET @Salt = CAST(N'' AS xml).value('xs:base64Binary(sql:variable("@SaltBytes"))', 'varchar(44)');
        SET @Hash = CONVERT(varchar(40), HASHBYTES('SHA1', @Password + @Salt), 2);

        EXEC dbo.p_Sys_User_ResetPassword @UserName, @Hash, @Salt, @Reason, @ChangeBy;

        IF @@TRANCOUNT <> 1
            THROW 50006, 'Reset procedure changed the migration transaction count.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Sys_Users
                       WHERE UserId = @UserId
                         AND Password COLLATE Latin1_General_100_BIN2 = @Hash
                         AND Salt COLLATE Latin1_General_100_BIN2 = @Salt)
            THROW 50007, 'Reset did not persist the expected hash/salt; migration rolled back.', 1;

        SET @Updated = @Updated + 1;
        FETCH NEXT FROM UsersToReset INTO @UserId, @UserName, @Digits;
    END;
    CLOSE UsersToReset;
    DEALLOCATE UsersToReset;
    COMMIT TRANSACTION;
    SELECT @Updated AS UpdatedAccounts;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF CURSOR_STATUS('local', 'UsersToReset') >= 0 CLOSE UsersToReset;
    IF CURSOR_STATUS('local', 'UsersToReset') >= -1 DEALLOCATE UsersToReset;
    DROP TABLE #Targets;
    THROW;
END CATCH;

DROP TABLE #Targets;
