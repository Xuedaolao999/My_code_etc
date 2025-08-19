dm 'log' clear;
%let AfrsOdbcFileDsn= I:\MyDocu\ForecastDocu\_SubVersion\OFMForecastProduction.dsn;

LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=zxg;

proc sql;
 create table forecast.Fmap_BaseFmapData as 
 select *
 from Fmap.BaseFmapData;
quit; 


libname Forecast clear;



