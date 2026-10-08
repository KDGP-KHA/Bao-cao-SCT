-- Run during a maintenance window after backing up database/schema definitions.
-- SQL Server 2012 compatible; offline index builds can block application traffic.
-- Nonunique indexes preserve legacy duplicate semantics. No rows/grants are changed.
USE [baocaosct.khanhhoa.gov.vn];
GO
-- Reuse an equivalent covering index, including an index with the same ordered key prefix.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Report_DataImports') AND name='IX_ReportPerformance_Imports_Period')
 AND NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.name='IX_ReportPerformance_Imports_Period' AND i.object_id=OBJECT_ID('dbo.Report_DataImports')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=3
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='ForMonth')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='TypeReport')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=3 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Code'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Unit'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='PerformInPeriod'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='PerformPreviousPeriod'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='AccumulatedBeginingOfYear'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='ComparedSamePeriodLastYear'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsLate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='CreatedDate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='LastModifiedDate')))
 THROW 50125,'Conflicting or disabled index IX_ReportPerformance_Imports_Period; DBA review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.Report_DataImports')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=3
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='ForMonth')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='TypeReport')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=3 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Code'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Unit'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='PerformInPeriod'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='PerformPreviousPeriod'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='AccumulatedBeginingOfYear'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='ComparedSamePeriodLastYear'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsLate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='CreatedDate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='LastModifiedDate')))
 CREATE NONCLUSTERED INDEX IX_ReportPerformance_Imports_Period
 ON dbo.Report_DataImports(ForMonth,TypeReport,EnterpriseId)
 INCLUDE(IsDeleted,Code,Unit,PerformInPeriod,PerformPreviousPeriod,AccumulatedBeginingOfYear,ComparedSamePeriodLastYear,IsLate,CreatedDate,LastModifiedDate);
ELSE PRINT 'Equivalent coverage already exists: IX_ReportPerformance_Imports_Period';
GO
-- Reuse an equivalent covering index, including an index with the same ordered key prefix.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Report_DataImports') AND name='IX_ReportPerformance_Imports_EnterprisePeriod')
 AND NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.name='IX_ReportPerformance_Imports_EnterprisePeriod' AND i.object_id=OBJECT_ID('dbo.Report_DataImports')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=3
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='ForMonth')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=3 AND k.is_descending_key=0 AND c.name='TypeReport')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Code'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Unit'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='PerformInPeriod'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsLate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='CreatedDate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='LastModifiedDate')))
 THROW 50125,'Conflicting or disabled index IX_ReportPerformance_Imports_EnterprisePeriod; DBA review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.Report_DataImports')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=3
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='ForMonth')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=3 AND k.is_descending_key=0 AND c.name='TypeReport')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Code'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Unit'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='PerformInPeriod'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsLate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='CreatedDate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='LastModifiedDate')))
 CREATE NONCLUSTERED INDEX IX_ReportPerformance_Imports_EnterprisePeriod
 ON dbo.Report_DataImports(EnterpriseId,ForMonth,TypeReport)
 INCLUDE(IsDeleted,Code,Unit,PerformInPeriod,IsLate,CreatedDate,LastModifiedDate);
ELSE PRINT 'Equivalent coverage already exists: IX_ReportPerformance_Imports_EnterprisePeriod';
GO
-- Reuse an equivalent covering index, including an index with the same ordered key prefix.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Report_ReportFiles') AND name='IX_ReportPerformance_Files_Period')
 AND NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.name='IX_ReportPerformance_Files_Period' AND i.object_id=OBJECT_ID('dbo.Report_ReportFiles')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='ForMonth')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsLate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='CreatedDate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='LastModifiedDate')))
 THROW 50125,'Conflicting or disabled index IX_ReportPerformance_Files_Period; DBA review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.Report_ReportFiles')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='ForMonth')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsLate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='CreatedDate'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='LastModifiedDate')))
 CREATE NONCLUSTERED INDEX IX_ReportPerformance_Files_Period
 ON dbo.Report_ReportFiles(ForMonth,EnterpriseId)
 INCLUDE(IsDeleted,IsLate,CreatedDate,LastModifiedDate);
ELSE PRINT 'Equivalent coverage already exists: IX_ReportPerformance_Files_Period';
GO
USE [baocaosct.khanhhoa.gov.vn.cate];
GO
-- Reuse an equivalent covering index, including an index with the same ordered key prefix.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Cate_Enterprises') AND name='IX_ReportPerformance_Enterprises_Id')
 AND NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.name='IX_ReportPerformance_Enterprises_Id' AND i.object_id=OBJECT_ID('dbo.Cate_Enterprises')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=1
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsActive'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsApproved'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='TaxCode'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='TypeBusiness'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='WardId'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='BusinessName')))
 THROW 50125,'Conflicting or disabled index IX_ReportPerformance_Enterprises_Id; DBA review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.Cate_Enterprises')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=1
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='EnterpriseId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsActive'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsDeleted'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='IsApproved'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='TaxCode'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='TypeBusiness'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='WardId'))
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='BusinessName')))
 CREATE NONCLUSTERED INDEX IX_ReportPerformance_Enterprises_Id
 ON dbo.Cate_Enterprises(EnterpriseId)
 INCLUDE(IsActive,IsDeleted,IsApproved,TaxCode,TypeBusiness,WardId,BusinessName);
ELSE PRINT 'Equivalent coverage already exists: IX_ReportPerformance_Enterprises_Id';
GO
-- Reuse an equivalent covering index, including an index with the same ordered key prefix.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Cate_EnterprisePermissions') AND name='IX_ReportPerformance_Assignments_UserEnterprise')
 AND NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.name='IX_ReportPerformance_Assignments_UserEnterprise' AND i.object_id=OBJECT_ID('dbo.Cate_EnterprisePermissions')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='ForUser')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='EnterpriseId'))
 THROW 50125,'Conflicting or disabled index IX_ReportPerformance_Assignments_UserEnterprise; DBA review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.Cate_EnterprisePermissions')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='ForUser')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='EnterpriseId'))
 CREATE NONCLUSTERED INDEX IX_ReportPerformance_Assignments_UserEnterprise
 ON dbo.Cate_EnterprisePermissions(ForUser,EnterpriseId);
ELSE PRINT 'Equivalent coverage already exists: IX_ReportPerformance_Assignments_UserEnterprise';
GO
-- Reuse an equivalent covering index, including an index with the same ordered key prefix.
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Sys_Permissions') AND name='IX_ReportPerformance_Permissions_RoleFunction')
 AND NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.name='IX_ReportPerformance_Permissions_RoleFunction' AND i.object_id=OBJECT_ID('dbo.Sys_Permissions')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='RoleId')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='FunctionId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Action')))
 THROW 50125,'Conflicting or disabled index IX_ReportPerformance_Permissions_RoleFunction; DBA review required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.Sys_Permissions')
 AND i.type IN(1,2)
 AND i.is_disabled=0
 AND i.is_hypothetical=0
 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name='RoleId')
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name='FunctionId')
 AND (i.type=1 OR EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name='Action')))
 CREATE NONCLUSTERED INDEX IX_ReportPerformance_Permissions_RoleFunction
 ON dbo.Sys_Permissions(RoleId,FunctionId) INCLUDE(Action);
ELSE PRINT 'Equivalent coverage already exists: IX_ReportPerformance_Permissions_RoleFunction';
GO
