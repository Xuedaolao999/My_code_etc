/**********************************************************************************
* Author: ZXG
* Date: 9/26/2020
* Purpose: to align the time window for Prepaid and PostPaid so that FAMP and payment method are consistent
           in terms of timing. 
************************************************************************************/
/*option mlogic mprint;*/
dm 'log' clear;
%let cycle = 2312;
%let FMAP_File = Mapredallocation_fid32;
/* use the FAMP file from 2105*/
/*%let FMAP_File = mapredictedfundallocation;*/

/*Create the copy of the MaPredictedFMAP in the work library*/
libname Checking "Q:\ForecastOFM\Production\NwCycle&cycle._01\Data\SourceIn";
Data Fmap Fmap_org;
  set Checking.&FMAP_File;
run; 

/* cells needed to be adjusted */

%let loc = %str(Q:\ForecastOFM\Production\NwCycle&cycle._02\ForecastPTFmap\WorkingProgs);
%let cell_list = prepay post pay FMAP FC2312.xlsx;

PROC IMPORT OUT= cell_list DATAFILE= "&loc.\&cell_list" DBMS=EXCEL REPLACE ;
  GETNAMES=YES;
  RANGE="Sheet1$";
  MIXED=NO;
  SCANTEXT=YES;
  USEDATE=YES;
  SCANTIME=YES;
RUN;

data cell_list;
  set cell_list;
  where PayOffset^=0;
run; 



%macro forward_cell( ForecastMeg = 1221,ForecastSvc = 630,PayOffset = 1);

/*Move the value in an ealier date to later date*/
/*dm 'log' clear;*/
%let PayOffset=&PayOffset;
%let lagstep = %eval(&PayOffset*4);
data adjusted_input;
  set Fmap;
  where ForecastMeg = "&ForecastMeg" and ForecastSvc = "&ForecastSvc";;
/*  lag_ServiceMonth = lag&lagstep.(ServiceMonth);*/
  new_MaPredictedFundAllocation = lag&lagstep.(MaPredictedFundAllocation);
run; 

data adjusted_input;
  set adjusted_input;
  if new_MaPredictedFundAllocation=  . then new_MaPredictedFundAllocation = MaPredictedFundAllocation;
run; 

/*proc print data=adjusted_input;*/
/*  where ServiceMonth between 201904 and 202004 and FundAllocationType = "F";*/
/*run; */

/*update the FMAP with shifted FMAP values */
proc sql;
  update Fmap as a
     set  MaPredictedFundAllocation = (select new_MaPredictedFundAllocation format = 10.6
                                       from  adjusted_input as b
									   where a.ForecastMeg = b.ForecastMeg 
                                             and a.ForecastSvc = b.ForecastSvc
											 and a.ServiceMonth = b.ServiceMonth
											 and a.FundAllocationType = b.FundAllocationType
									   )
  where a.ForecastMeg = "&ForecastMeg" and a.ForecastSvc = "&ForecastSvc"; 
quit;

%mend;

/*%forward_cell;*/
%macro backward_cell( ForecastMeg = 1221,ForecastSvc = 350,PayOffset = -3);
  data cell;
    set Fmap;
  /*  where ForecastMeg = "1221" and ForecastSvc = "630";*/
    where ForecastMeg = "&ForecastMeg" and ForecastSvc = "&ForecastSvc";
  run; 

  proc sort data = cell out =cell_back;
    by descending ServiceMonth;
  run; 
  
  %let PayOffset=%sysfunc(abs(&PayOffset));
  %let lagstep = %eval(&PayOffset*4);
  
  data cell_back_1;
    set cell_back;
    new_MaPredictedFundAllocation = lag&lagstep.(MaPredictedFundAllocation);;
  run; 

  proc sort data = cell_back_1 out = adjusted_input;
    by ServiceMonth;
  run;
  
  data adjusted_input;
    set adjusted_input;
    if new_MaPredictedFundAllocation=  . then new_MaPredictedFundAllocation = MaPredictedFundAllocation;
  run; 


  proc sql;
  update Fmap as a
     set  MaPredictedFundAllocation = (select new_MaPredictedFundAllocation format = 10.6
                                       from  adjusted_input as b
									   where a.ForecastMeg = b.ForecastMeg 
                                             and a.ForecastSvc = b.ForecastSvc
											 and a.ServiceMonth = b.ServiceMonth
											 and a.FundAllocationType = b.FundAllocationType
									   )
  where a.ForecastMeg = "&ForecastMeg" and a.ForecastSvc = "&ForecastSvc"; 
  quit;

%mend; 
/*%backward_cell;*/


%macro loop_cell;
  %let dsid = %sysfunc(open(cell_list));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
     %PUT NOTE:  I am in cell >>>>>>(&ForecastMeg, &ForecastSvc, &PayOffset)<<<<< ;
	 %if %eval(&PayOffset<0) %then %do;
        %put i am negative;
		%backward_cell(ForecastMeg = &ForecastMeg,ForecastSvc = &ForecastSvc,PayOffset = &PayOffset);
		%end;
	 %else %do;
        %put i am positive;
		%forward_cell( ForecastMeg = &ForecastMeg,ForecastSvc = &ForecastSvc,PayOffset = &PayOffset);
     %end;
   %end;
  %let rc = %sysfunc(close(&dsid));
%mend;   

%loop_cell;

%let dt=%sysfunc(today(),date9.);

 data Checking.Mapredallocation_&cycle._&dt;
   set Fmap;
 run; 

libname Checking clear;

/* check the value before and after udpated */
%let ts_meg=1271;
%let ts_svc=610;


proc sql;
  create table test&ts_meg._&ts_svc as 
  select a.ForecastMeg, a.ForecastSvc,a.ServiceMonth,a.FundAllocationType,
         a.MaPredictedFundAllocation as new_MaPredictedFundAllocation format = 10.6,b.MaPredictedFundAllocation,
		 input(put(a.ServiceMonth,z6.),yymmn6.) as date
  from Fmap as a 
  inner join Fmap_org as b
  on a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc
     and a.ServiceMonth = b.ServiceMonth and a.FundAllocationType = b.FundAllocationType
  where a.ForecastMeg = "&ts_meg" and a.ForecastSvc = "&ts_svc" 
/*  and a.ServiceMonth  between 202002 and 202306 */
        and a.FundAllocationType = "F"
		and a.MaPredictedFundAllocation ^= b.MaPredictedFundAllocation
  order by a.ForecastMeg, a.ForecastSvc,a.ServiceMonth,a.FundAllocationType;
quit;


ods graphics on / width = 8.5 in height=4.5 in ;

proc sgplot data=test&ts_meg._&ts_svc ASPECT = 0.5 CYCLEATTRS DESCRIPTION="Forecasting plot"  NOOPAQUE;
  Title1  j=c h=1.0 c=red  "FMAP of &ts_meg._&ts_svc" ;
  series x=date y=new_MaPredictedFundAllocation / lineattrs= (pattern=1 thickness =2 color = r ) 
        LEGENDLABEL = "Adjusted FMAP" name = "fc" MARKERS MARKERATTRS = (symbol=TriangleRightFilled color=purple  size = 5px);

  series x=date y=MaPredictedFundAllocation /  lineattrs=(pattern=1 thickness=2 color = blue ) 
                           LEGENDLABEL = "Original FMAP" name = "stfc"
                                   Markers MARKERATTRS = (symbol=Triangle color=purple size = 5px) ;
  
  xaxis label = "ServiceMonth"  minor MINORCOUNT = 2 type = time TICKVALUEFORMAT=MONYY7. fitpolicy = ROTATETHIN GRID ;

  yaxis label = "FMAP" ;
run;
quit;


proc print data = test&ts_meg._&ts_svc;
run;


proc print data = Fmap_org;
  where ForecastMeg = "&ts_meg" and ForecastSvc = "&ts_svc" and FundAllocationType = "G";
run; 
