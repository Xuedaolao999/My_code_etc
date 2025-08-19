dm 'log' clear;
%let AfrsOdbcFileDsn= Q:\ForecastOFM\Production\NwCycle1912_01\Home\SourceInformation\OFMForecastProduction.dsn;
%let destionation = Q:\ForecastOFM\Production\NwCycle1912_03\Data\P1data;

LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=dbo;
LIBNAME P1 "&destionation";

proc sql;
 create table P1.mc_ffs_split as 
 select *
 from forecast.Temp_MC_FFS_SPLIT;

 create table P1.rac as 
 select Forecast_Meg, Forecast_SVC, mnth_of_srvc, RPRTBL_RAC_CODE, RPRTBL_RAC_NAME, PAID_AMOUNT, USER_COUNT, PER_USER_COST, ELIGIBLES, P1_PERCAP, UTILIZATION 
 from forecast.Temp_RAC;

 create table P1.Calib_p1 as
 select *
 from forecast.Temp_Calib_p1;

 create table P1.duals as 
 select *
 from forecast.Temp_DUALS;

 create table p1.adult_kids as 
 select *
 from forecast.Temp_Adult_kids;

 create table p1.MC_summary as 
 select *
 from forecast.Temp_MC_summary;

quit; 

libname P1 clear;
libname Forecast clear;


