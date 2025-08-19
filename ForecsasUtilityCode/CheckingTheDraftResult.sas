
/**********************************************************************************
* After we done all the PT forecast and the step are added, the first version is 
* realeased to HCA, not for legislature yet, we will check if the forecast 
* has any issue needed to address before we create the final release to legislature people
*******************************************************************************************/

dm 'log' clear;

/*Importing the file ForecastFilterFile_1717_D01_M01.csv */
proc import datafile="\\profiles.eclient.wa.lcl\ofmprofile$\xingguoZ\desktop\checkingFolder\ForecastFilterFile_1717_D01_M01.csv" 
   out=Source_D01_M01 dbms=csv replace; 
   getnames=yes; 
run;

proc print data = Source_D01_M01 (obs =100);
run; 

data source;
 set Source_D01_M01;
  Eligible = input(Eligible,comma15.);
  Total = input(Total,dollar15.);
run; 


proc sql;
  select distinct ForecastVersion, FiscalYear
  from source;
quit; 

data test;
  set source;
  Eligible_lag = lag(Eligible);
  Total_lag = lag(Total);
  Federal_lag = lag(Federal);
  State_lag = lag(State);
  SNAF_lag = lag(SNAF);
  where ForecastMeg = 1211 and  ForecastSvc = 101;
run; 



proc print data = test;
run; 

/* Looking at the percentage*/
data percentage  ;
  set test;
  *if MonthOfService>='01Aug2016'd;
  Eligible_Pctchange = (Eligible-Eligible_lag)/Eligible_lag;
  Total_PctChange = ifn((Total-Total_lag)=0,0,ifn(Total_lag= 0 and (Total-Total_lag) ^=0, 100000,(Total-Total_lag)/Total_lag)) ;
  Eligible_change = (Eligible-Eligible_lag);
  Total_Change =(Total-Total_lag);
  format Total_PctChange  Eligible_Pctchange percent10.5;
run; 

/* print the extremely change of the total or eligible */

proc print data = percentage;
  where abs(Total_PctChange)>=50 /*or abs(Eligible_Pctchange)>0.015*/;
run; 

proc print data =percentage;
run; 

/*
ForecastMeg ForecastSvc MonthOfService FiscalYear BudgetUnit ExpenditureSource ForecastVersion Eligible Total Federal State SNAF 

*/

/*Below, we will look at the cells where the predicted vaulue is 3 times of the historic valuel */
