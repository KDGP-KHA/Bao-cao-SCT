-- Run manually AFTER deploying the four dashboard SP contracts.
-- All statements below are reads. No database objects or rows are changed.
USE [baocaosct.khanhhoa.gov.vn];

-- Full expected populations (October baseline: 18854 / 2 / 33).
EXEC dbo.p_Report_Dashboard_OverviewSummary @ForMonth='20261001';
EXEC dbo.p_Report_Dashboard_OverviewSummary @ForMonth='20261001',@GroupBy='ward';
EXEC dbo.p_Report_Dashboard_OverviewSummary @ForMonth='20261001',@GroupBy='sector';

-- Sparse observations, not expected-population grids.
-- Imported / complete metrics: type1 60/22; type2 1/0; type3 2/2.
EXEC dbo.p_Report_Dashboard_IndustrialSnapshot @ForMonth='20261001',@TypeReport=1;
EXEC dbo.p_Report_Dashboard_IndustrialSnapshot @ForMonth='20261001',@TypeReport=2;
EXEC dbo.p_Report_Dashboard_IndustrialSnapshot @ForMonth='20261001',@TypeReport=3;

-- September has file evidence but no active economic values.
EXEC dbo.p_Report_Dashboard_IndustrialSnapshot @ForMonth='20260901',@TypeReport=1;

-- Real filter keys from audited source; conjunction must not duplicate amounts.
EXEC dbo.p_Report_Dashboard_IndustrialSnapshot @ForMonth='20261001',@TypeReport=1,@EnterpriseId=446;
EXEC dbo.p_Report_Dashboard_IndustrialSnapshot @ForMonth='20261001',@TypeReport=1,@WardId=2066,@EconomicSectorId=2,@IndustryId=2845;

-- Status totals: all18854, missing18794, incomplete38, complete22, conflict0.
EXEC dbo.p_Report_Dashboard_ProgressDetails @ForMonth='20261001',@TypeReport=1,@Status='all',@Page=1,@PageSize=50;
EXEC dbo.p_Report_Dashboard_ProgressDetails @ForMonth='20261001',@TypeReport=1,@Status='all',@Page=2,@PageSize=50;
EXEC dbo.p_Report_Dashboard_ProgressDetails @ForMonth='20261001',@TypeReport=1,@Status='missing';
EXEC dbo.p_Report_Dashboard_ProgressDetails @ForMonth='20261001',@TypeReport=1,@Status='incomplete';
EXEC dbo.p_Report_Dashboard_ProgressDetails @ForMonth='20261001',@TypeReport=1,@Status='complete';
EXEC dbo.p_Report_Dashboard_ProgressDetails @ForMonth='20261001',@TypeReport=1,@Status='conflict';

-- Stable, paginated options and latest source month (October2026).
EXEC dbo.p_Report_Dashboard_FilterOptions @OptionKind='latest';
EXEC dbo.p_Report_Dashboard_FilterOptions @OptionKind='ward',@TypeReport=1;
EXEC dbo.p_Report_Dashboard_FilterOptions @OptionKind='industry',@TypeReport=1;
EXEC dbo.p_Report_Dashboard_FilterOptions @OptionKind='enterprise',@TypeReport=1,@Page=1,@PageSize=50;
EXEC dbo.p_Report_Dashboard_FilterOptions @OptionKind='enterprise',@TypeReport=1,@Page=2,@PageSize=50;

-- Reused original raw detail reader; works for mid-month ForMonth records.
EXEC dbo.p_Report_DataImports_GetDataImport @EnterpriseId=446,@ForMonth='20261001';
