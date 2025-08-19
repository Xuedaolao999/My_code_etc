/*************************************************************************************
  To create the A version similar to A version in the SQL server production data
  input data: MA predicted, FAMP data, and the eligible;
  Note: the FAMP is used to calculate the expenditure of total, Federal, state in the predicting period; we have actutal 

        data for total, federal, and date in the history. 
        Eligible is calculated based on the split between MC and FFS split, table Maindm.Fact_ier_eligiblemcenrollpct 
        contains the records. 
        1. the eligibe split is average from Nov2017 and May2018 in forecast cycle 1917!!
        2. MEGs that has split between MC and FFS:1210, 1220,1250,1260,1270,1620,1860, but I do not see the split of 1620 in the production data.
Note: 1. when checking my data against the production data, remember that, since my development is based on 
                forecasting cycle 1917, the 2018 July and forward is forecasting data, and June 2018 backward is the 
                actual data. 
      2. Observation for MEGS without split: actual/historical eligible data between my eligible and production agree with each other before and including 201807 (for forecasting cycle 1917);
         so forecasted eligible data should begin from 201808
      3. Notice that the actual/historical eligible is using table zxg.cfcscrub_eligibles where scrub_month= 1917; but for the predicting period eligible data 
         the process is using zxg.cfcscrub_eligibles_fc where forecast_month = 'FC1918'; not the one with forecast_month = 'FC1914', 
         the reason is because we have more updated data, then we just use the newly updated data if it is avaliable. 
      4. In the production process when populating the table dbo.trackingDetail_history in SQL server, only MA_predicted_percap's PerCap in prediction period is used 
         to caclulate the expenditure of Total, Federal, State; for the actual period, the acutal data from AFRS extract is used to calculate the total, federal and 
         state expenditure, MA_predicted_percap data is not used!!!

 
Progress : 1: MEGs without split in the predicting period: done
       2: Eligibles for MEGs without split in the hisotical and predicting period: done!
       3: Eligible for MEGs with split in the actual period and predict period:  done!
       4: Expenditure in the predicting period: done
       5: VWCODE.VW_CYCLECELLMAP is used to find the budget unit for a cell !!!

Questions: 
       1. for the megs with split, in the foreasting period, my eligible is not equal for them month 
          between 201807 and 201809, then from 201810 and forward my eligible and the eligible from 
          production is same, but why those eligible from 201807 and 201809 are different?
          Answer: This is because that the splits for these three month are just the ratio of mccount/(mccount+ffscount), referring table Special_Meg_with_split
                  below, but the ratio is applied in the data cfcscrub_eligibles_fc, not in the cfcscrub_eligibles!!!
   
************************************************************************************/

dm 'log' clear;
option mprint mlogic;
filename maclib 'C:\MyDocu\ForecastDocu\_SubVersion\SASMacros';
options mautosource sasautos =(SASAUTOS maclib); 

/* Defines cycle */
%let cycle = 1924;
%let ReleaseVerLetter = A01;

/*time window to determine the MC and FFS split */
%let SplitBeg = 201807;
%let SplitEnd = 201812;

/* chopped month that need to calculate the MC and FFS split. This time window is always chosen from the 
   last 2 months that is from dbo.cfcscrub_eligibles data. For example,the scrub month for which the monthly CFC data was used 
   in forecast productoion cycle 1924 (October 2019)is 1924; and when scrub_month is 1924, the last 2 months of the data in table 
   dbo.cfcscrub_eligibles are 201903 and 201904,therefore we choose the following time widow. Keep in mind taht the ratio calculated using this 
   time window is applied not in the monthly CFC data, but in the FC CFC data used in the production. 
   
*/
%let ChoppedBeg = 201903;
%let ChoppedEnd = 201904;

/* create the month for the acutal period */
%let FromDt = 201207;
%let ToDt = 201902; /*last month of the actual period */
%let ToFCDt = 202106; /*last month of the Forecasting period */

/*some megs just do not have eligibles, and managed in the following way, the following format, as illustration, 1500_1 means for meg 1500, the eligble is 1 all the time;
  the followng macro variable is called by sas macro sqlstatement.sas.
*/
%let meg_elgle = 1500_1,1974_1,1998_1;

/* the choice to select the cfc caseload fc data, not the monthly cfc caseload data */
%let cfcscrub_eligibles_fc_month = %upcase(fc2102);

%CreatContMonth(start = &FromDt,act_end = &ToDt,fc_end = &ToFCDt);

Proc Format;
  picture mydtfmt
  low-high = '%0m-%0d-%Y @ %0I.%0M %p' (datatype=datetime);
Run;

Proc PrintTo 
LOG="C:\MyOwn_A_Version_%unquote(%sysfunc(datetime(),mydtfmt.)).txt" ;
Run;



libname src "Q:\ForecastOFM\Production\NwCycle&cycle._01\Data\SourceIn";
%let meg_lst = %str("1210", "1220","1250","1260","1270","1620","1860");

data MA_predicted_percap;
  set src.mapredictedpercap;
run; 

data Predicted_FAMP;
  set src.mapredictedfundallocation;
run; 

data Ma_predicted_eligible;
  set src.mapredictedeligible;
run; 

libname src clear;


/* get data from SQL server */
%let AfrsOdbcFileDsn= C:\MyDocu\ForecastDocu\_SubVersion\OFMForecastProduction.dsn;

LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=zxg;

proc sql;
 create table scrub_eligible as 
 select *, mccount/(mccount+ffscount) as Ratio
 from Forecast.cfcscrub_eligibles
 where scrub_month = "&cycle" ;

 /* MEGs with split 1210, 1220,1250,1260,1270,1620,1860*/
  create table Meg_with_split as 
  select forecast_caseload_meg,avg(Ratio) as split
  from scrub_eligible
  where input(month_of_service,6.) between &SplitBeg and &SplitEnd /* this is the time window to determine the MC and FFS split*/
       and forecast_caseload_meg in (&meg_lst)
  group by forecast_caseload_meg;

  /* create the split for chopped month in monthly cfc  */
  create table Special_Meg_with_split as 
  select forecast_caseload_meg,month_of_service,Ratio as split
  from scrub_eligible
  where input(month_of_service,6.) between &ChoppedBeg and &ChoppedEnd /* these 2 months data are chopped due to not mature*/
       and forecast_caseload_meg in (&meg_lst);

  create table cfcscrub_eligibles_fc as 
  select *
  from Forecast.cfcscrub_eligibles_fc
  where upcase(forecast_month) = "&cfcscrub_eligibles_fc_month";
 
quit; 

libname Forecast clear;

/* Eligible not splitted */
 proc sql;
 create table predicted_eligible_no_split as 
 select a.cfc_caseload_meg,a.month_of_srvc,round(a.rawdata,1) as eligible
 from cfcscrub_eligibles_fc as a 
 where input(month_of_srvc,6.)>&ToDt and a.cfc_caseload_meg not in (&meg_lst)
 order by  a.month_of_srvc;

 create table  actual_eligible as 
 select forecast_caseload_meg, month_of_service, round(rawdatalagged,1) as eligible
 from scrub_eligible
 where  input(month_of_service,6.) between &FromDt and &ToDt 
        and forecast_caseload_meg not in (&meg_lst);

 /* put together the actual and predicted eligible */
 create table EligibleNoSplit as 
 select forecast_caseload_meg, month_of_service,eligible
 from actual_eligible
 union 
 select cfc_caseload_meg,month_of_srvc,eligible
 from predicted_eligible_no_split 
 order by month_of_service;
 quit; 

/* Eligible splitted   */
 proc sql;
  create table Actual_Eligible_splitted as
   select a.forecast_caseload_meg, a.month_of_service, round(a.rawdatalagged*Ratio,1) as mccount, round(a.rawdatalagged*(1-Ratio),1) as ffscount
   from scrub_eligible as a
   inner join Meg_with_split as b
     on a.forecast_caseload_meg = b.forecast_caseload_meg 
   where  input(month_of_service,6.) between &FromDt and &ToDt
   order by a.forecast_caseload_meg, a.month_of_service;

   create table predicted_Eligible_splitted as 
   select a.cfc_caseload_meg,a.month_of_srvc,round(a.rawdata*b.split,1) as mccount, round(a.rawdata*(1-b.split),1) as ffscount
   from cfcscrub_eligibles_fc as a 
   inner join Meg_with_split as b
     on a.cfc_caseload_meg = b.forecast_caseload_meg
   where input(a.month_of_srvc,6.)>&ChoppedEnd; 

   create table spec_predicted_Eligible_splitted as 
   select a.cfc_caseload_meg,a.month_of_srvc,round(a.rawdata*b.split,1) as mccount, round(a.rawdata*(1-b.split),1) as ffscount
   from cfcscrub_eligibles_fc as a 
   inner join Special_Meg_with_split as b
     on a.cfc_caseload_meg = b.forecast_caseload_meg and a.month_of_srvc = b.month_of_service;
/*   where input(month_of_srvc,6.)between 201808 and 201809; */

   create table CountWithSplit as 
   select  cfc_caseload_meg,month_of_srvc,mccount, ffscount
   from predicted_Eligible_splitted
   union
   select cfc_caseload_meg,month_of_srvc,mccount, ffscount
   from spec_predicted_Eligible_splitted
   order by cfc_caseload_meg, month_of_srvc;
  
   /* put together the actual and predicted eligible */
   create table EligibleWithSplit as 
   select distinct substr(cfc_caseload_meg,1,3)||"1" as forecast_caseload_meg,month_of_srvc,mccount as Eligible
   from CountWithSplit 
   union  
   select distinct substr(cfc_caseload_meg,1,3)||"2",month_of_srvc,ffscount as Eligible
   from CountWithSplit 
   union
   select distinct substr(forecast_caseload_meg,1,3)||"1",month_of_service,mccount
   from Actual_Eligible_splitted
   union
   select distinct substr(forecast_caseload_meg,1,3)||"2",month_of_service,ffscount
   from Actual_Eligible_splitted
   order by forecast_caseload_meg,month_of_srvc;
   
 quit;  

/* put the total eligible together in one table */

proc sql;
  create table Final_eligible as 
  select forecast_caseload_meg,month_of_srvc, Eligible 
  from EligibleWithSplit 
  union 
  select forecast_caseload_meg,month_of_service, Eligible
  from EligibleNoSplit
  union
  %sqlstatement;
quit; 


/*A-version expenditure in the prediction period */
proc sql;
  create table predicted_expenditure as 
  select distinct a.ForecastMeg,a.ForecastSvc,a.ServiceMonth,a.MaPredictedPercap*b.eligible as Total,
         a.MaPredictedPercap*b.eligible*c.MaPredictedFundAllocation as Federal,
         a.MaPredictedPercap*b.eligible*d.MaPredictedFundAllocation as State,a.MaPredictedPercap*b.eligible*f.MaPredictedFundAllocation as SNAF, 
         a.MaPredictedPercap*b.eligible*e.MaPredictedFundAllocation as Local,0 as Tobacco, 0 as HSA
/*         b.eligible,a.MaPredictedPercap as PerCap*/
  from MA_predicted_percap as a
  inner join Final_eligible as b
    on a.ForecastMeg = b.forecast_caseload_meg and a.ServiceMonth = input(b.month_of_srvc,6.)
  left join Predicted_FAMP as c
    on a.ForecastMeg = c.ForecastMeg and a.ForecastSvc =c. ForecastSvc and a.ServiceMonth =c.ServiceMonth and c.FundAllocationType = "F"
  left join Predicted_FAMP as d
     on a.ForecastMeg = d.ForecastMeg and a.ForecastSvc =d.ForecastSvc and a.ServiceMonth = d.ServiceMonth and d.FundAllocationType = "G"
  left join Predicted_FAMP as e
     on a.ForecastMeg = e.ForecastMeg and a.ForecastSvc =e.ForecastSvc and a.ServiceMonth = e.ServiceMonth and e.FundAllocationType = "L"
  left join Predicted_FAMP as f
     on a.ForecastMeg = f.ForecastMeg and a.ForecastSvc =f.ForecastSvc and a.ServiceMonth = f.ServiceMonth and f.FundAllocationType = "N"
   where a.ServiceMonth>=&ChoppedBeg /* define the predicting period */
  order by a.ForecastMeg,a.ForecastSvc,a.ServiceMonth;
quit; 

/* Calculate the acutal expenditure  -----------------------------------------------------------------------------------------*/
libname VWCODE  "Q:\ForecastOFM\Production\NwCycle&cycle._01\home\Forecast Process Specific Files\ViewsCode";
libname MainDm  "Q:\ForecastOFM\Production\NwCycle&cycle._01\Data\MainDm";

proc sql;
  create table cell as 
  select distinct ForecastMeg, ForecastSvc 
  from MA_predicted_percap
  order by 1,2;
quit; 

/* checking ++++++++++++++++++++++ since 1253*/
/*data cell;*/
/*  set cell;*/
/*  where ForecastSvc = "211" and ForecastMeg = "1253";*/
/*run; */

proc sql;

 CREATE table Vw_AfrsSumLagExpMos_zxg AS 
 SELECT DISTINCT a.Afrs_Cycle_ID, a.Afrs_Meg_ID, a.Afrs_Svc_ID, a.CalendarYearMonth_ID, a.FundType,                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
        sum(a.AfrsExpenditure*b.AfrsExpenditureLag) as AfrsExpenditure                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
 FROM (SELECT x.*, y.Afrs_Svc_ID, y.Afrs_Meg_ID, z.FundType_ID,   z.FundType                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
       FROM MainDm.Fact_Afrs_Expenditure as x 
       inner join MainDm.Map_Afrs_Expenditure as y
         on x.Afrs_ExpenditureMapping_ID=y.Afrs_ExpenditureMapping_ID 
       inner join MainDm.Dim_Afrs_ExpAuthIndex as w 
	     on y.Afrs_ExpAuthIndex_ID=w.Afrs_ExpAuthIndex_ID 
	   inner join MainDm.Dim_FundType as z
         on w.FundType=z.FundType
       ) a                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
 inner join MainDm.Fact_Afrs_ExpenditureLag as b
    on  a.Afrs_Cycle_ID=b.Afrs_Cycle_ID AND a.CalendarYearMonth_ID=b.CalendarYearMonth_ID AND  a.Afrs_Svc_ID=b.Afrs_Svc_ID                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
  GROUP BY a.Afrs_Cycle_ID, a.Afrs_Meg_ID, a.Afrs_Svc_ID, a.CalendarYearMonth_ID,a.FundType;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     

  CREATE table Vw_ForLagExpMos_zxg AS
  SELECT DISTINCT d.AfrsCycle, e.ForMeg, f.ForSvc, h.CalendarYearMonth as ServiceMonth, h.FiscalYear, FundType, sum(a.AfrsExpenditure) as ForExpenditure
  FROM Vw_AfrsSumLagExpMos_zxg as a 
  inner join VwCode.Vw_AfrsForMegMap as b 
    on a.Afrs_Meg_ID=b.Afrs_Meg_ID
  inner join VwCode.Vw_AfrsForSvcMap as c 
    on a.Afrs_Svc_ID=c.Afrs_Svc_ID
  inner join MainDm.Dim_For_Meg as e
    on b.For_Meg_ID=e.For_Meg_ID
  inner join MainDm.Dim_For_Svc as f
    on c.For_Svc_ID=f.For_Svc_ID
  inner join MainDm.Dim_Afrs_Cycle d
    on a.Afrs_Cycle_ID=d.Afrs_Cycle_ID 
  inner join MainDm.Dim_CalendarYearMonth as h
    on a.CalendarYearMonth_ID=h.CalendarYearMonth_ID   
  where  d.AfrsCycle = "&cycle" and h.CalendarYearMonth<=&ToDt /* define the last month of the actual*/
  GROUP BY AfrsCycle, e.ForMeg, f.ForSvc, ServiceMonth,FundType;
quit;



proc sql;
  create table actual_expenditure   (ForecastMeg varchar(4),
                                     ForecastSvc varchar(3),
                                     MonthOfService int,
                                     Total numeric,
                                     Federal numeric,
                                     State numeric,
									 SNAF numeric,
									 Local numeric,
									 Tobacco numeric,
									 HSA numeric


						 );

  
quit; 

%cal_actual_exp;

/*put together the expenditure of actual and predicted */
Proc sql;
  create table Expenditure_past_and_future as 
  select ForecastMeg,ForecastSvc,MonthOfService,Total format =14.2 ,Federal format =14.2,State format =14.2,SNAF format =11.4,Local format =11.4,Tobacco,HSA
  from ACTUAL_EXPENDITURE 
  union
  select ForecastMeg,ForecastSvc,ServiceMonth,Total,Federal,State,SNAF,Local,Tobacco,HSA
  from predicted_expenditure
  order by ForecastMeg,ForecastSvc,MonthOfService;
quit; 

/*produce my A version */

proc sql;
  create table my_A_Version   (ForecastMeg varchar(4),
                               ForecastSvc varchar(3),
                               MonthOfService varchar(6),
							   FiscalYear varchar(4),
							   BudgetUnit varchar(3),
							   Eligible numeric,
                               Total numeric,
                               Federal numeric,
                               State numeric,
							   SNAF numeric,
							   Local numeric,
							   Tobacco numeric,
							   HSA numeric,
							   PerCap numeric,
							   ThisCycle varchar(4),
                               ReleaseVerLetter varchar(3),
							   Created varchar(20),
							   CreatedBy varchar(10)
            				 );

/*  create table my_A_Version as */
 insert into my_A_Version (ForecastMeg,ForecastSvc,MonthOfService,FiscalYear,BudgetUnit,Eligible,Total,Federal,State,SNAF,Local,
                           Tobacco,HSA,PerCap,ThisCycle,ReleaseVerLetter,Created,CreatedBy)
  select a.ForecastMeg,a.ForecastSvc,put(a.MonthOfService,6.0),put(c.FiscalYear,4.0),b.BudgetUnit,d.Eligible,
         a.Total,a.Federal,a.State, a.SNAF, a.Local, a.Tobacco,a.HSA, a.Total/d.Eligible   format=12.4 as PerCap,
		 "&cycle" as ThisCycle,"&ReleaseVerLetter" as ReleaseVerLetter, "%sysfunc(datetime(),datetime19.)" as Created,'Xingguo' as CreatedBy
  from Expenditure_past_and_future as a 
  inner join VWCODE.VW_CYCLECELLMAP as b
    on a.ForecastMeg = b.ForMeg and a.ForecastSvc = b.ForSvc
  inner join MainDm.Dim_calendaryearmonth as c
    on a.MonthOfService = c.CalendarYearMonth
  inner join Final_eligible as d
    on a.ForecastMeg = d.forecast_caseload_meg and a.MonthOfService = input(d.month_of_srvc,6.)
  ;
quit;

libname VWCODE  clear; 
libname MainDm  clear;


/* Move the data to SQL server */
%macro Mov_to_Sql;
  LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=zxg;
  proc sql;
  %if %sysfunc(exist(forecast.my_A_Version))%then %do;
  %put the table exists;
	  drop table forecast.my_A_Version;
  %end;

 
  create table forecast.my_A_Version as 
  select *
  from my_A_Version;
  quit; 
  libname Forecast clear;
%mend;

%Mov_to_Sql;


Proc PrintTo;
Run;



/* checking */
/*LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=zxg;*/
/*proc sql;*/
/*  */
/*  create table my_A_Version_expenditure   (ForecastMeg varchar(4),*/
/*                               ForecastSvc varchar(3),*/
/*                               MonthOfService varchar(6),*/
/*							   Total numeric,*/
/*                               Federal numeric,*/
/*                               State numeric,*/
/*							   SNAF numeric,*/
/*							   Local numeric,*/
/*							   Tobacco numeric,*/
/*							   HSA numeric*/
/*							               				 );*/
/*  */
/*  insert into my_A_Version_expenditure */
/*  select a.ForecastMeg,a.ForecastSvc,put(a.MonthOfService,6.0),*/
/*         a.Total,a.Federal,a.State, a.SNAF, a.Local, a.Tobacco,a.HSA*/
/*  from Expenditure_past_and_future as a ;*/
/**/
/**/
/* create table forecast.my_A_Version_expenditure as */
/* select **/
/* from my_A_Version_expenditure;*/
/*quit; */
/**/
/**/
/*libname Forecast clear;*/
