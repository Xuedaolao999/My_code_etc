/********************************************************************************
* This code is to produec the so called step for 610,620,630 and other services that 
* need to use the predicted value to replace the actual value and apply the predictd
* FAMP. The difference of the predicted Percap and acutal Percap are divided between
* State and Federal using the predicted FMAP. The issue is due to HCA asking us to
* not use the July (when the rate change happens) in the Feb2019 cycle
*
*********************************************************************************/
dm 'log' clear;

options minoperator mindelimiter=','; 
/* the cells to be managed */

data cells;
  length Meg $4 svc $3 type $1;
  input meg svc type;
  datalines;
  1251 620 L
  1230 620 L
  1221 630 L
  1211 610 L
  1261 610 L
  1271 610 L
  1861 610 L
  1500 410 L
  1261 671 L
  1862 791 L
  1261 791 L
  1720 776 S
  1862 776 S
  1480 776 S
  1910 776 S
  1861 776 S
  1960 776 S
  1470 776 S
  1998 776 S
  1861 791 S
  1251 791 S
  1290 620 S
  1862 610 S
  1221 450 L
  1350 101 S

;
run; 


data cells;
  length Meg $4 svc $3 type $1;
  input meg svc type;
  datalines;
  1261 671 L 
  1861 671 S 

  ;
run; 

data cells;
  length Meg $4 svc $3 type $1;
  input meg svc type;
  datalines;
  1221   450	L
  1222   450	L
  1251   450	L
  1252   450	L
  1211   453	L
  1221   453	L
  1230   453	L
  1251   453	L
  1261   453	L
  1271   453	L
  1211   450	L
  1212   450	L
  1230   450	L
  1262   450	L
  1280   450	L
  1480   450	L
  1499   450	L
  1500   450	L

  ;
run; 

data cells;
  length Meg $4 svc $3 type $1;
  input meg svc type;
  datalines;
  1862 791 L 

  ;
run; 

proc print data = cells;
run; 


%let startMon = %str('01Jun2019'd);
%let mon = %str('01Jul2019'd);
%let cycle = 2117;

libname FP1 "Q:\ForecastOFM\Production\NwCycle&cycle._01\ForecastPTFmap\Forecast Process Specific Files\Cycle &&cycle.\Version A\Fmap";
libname FP2 "Q:\ForecastOFM\Production\NwCycle&cycle._02\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle.\Version A\Fmap";
libname FP3 "Q:\ForecastOFM\Production\NwCycle&cycle._03\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle.\Version A\Fmap";

%put >>>>>>>>>>>>>>>>>>>"Q:\ForecastOFM\Production\NwCycle&cycle._02\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle.\Version A\Fmap";

libname FPAll (FP1,FP2,FP3);

libname PT  "Q:\ForecastOFM\Production\NwCycle&cycle._01\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle.\Version A\Primary Trend"; 
%macro PT_patching (meg=, svc=, type=L);
 
 data PT_Missing_&meg._&svc;
   %if %upcase(&type)= L %then %do;
    set pt.R_&meg._&svc._newmodel_&cycle._1;
    keep Pred Date Act;
   %end; 
   %else %do;
     set PT.Ucmsts_&meg._&svc (rename = (predict = pred adjPercap = Act));
	 keep Pred Date Act;
	%end;
  run; 
  
 
 data input_&meg._&svc;
   set PT.Modelinput;
   where category = "&meg" and service = "&svc";
 run; 

 /* Get the FMAP data   */
 data famp_&meg._&svc;
   set FPAll.FmapRatio&meg._&svc;
 run; 
 
 %if &meg = 1261 and &svc = 671 %then %do;
   %let startMon =%str('01Feb2019'd);
 %end;
 %else %if &meg in (1500) and &svc = 450 %then %do;
   %let startMon =%str('01Nov2018'd);
 %end;
 %put NOTE: startMon is >>>>>>>>>>>>>>>>>>>>>&startMon;
 
 proc sql;
   create table patch_&meg._&svc as 
   select &meg as FcMeg, &svc as FcSvc,Year(a.Date)*100+month(a.Date) as ServiceMonth format=6.,
          'F' as FundType,
          (a.Pred-ifn(a.Act=.,ifn(b.perCap=.,0,b.perCap),a.Act))*d.ProjectedFmap*ifn(b.Eligibles =.,1,b.Eligibles) as AffectField
   from PT_Missing_&meg._&svc as a 
   inner join input_&meg._&svc as b
     on a.Date = b.mos
   inner join famp_&meg._&svc as d
     on a.Date = d.MOS
   where Date between &startMon and &mon
   union 
   select &meg as FcMeg, &svc as FcSvc,Year(a.Date)*100+month(a.Date) as ServiceMonth format=6.,
          'G' as FundType, 
          (a.Pred-ifn(a.Act=.,ifn(b.perCap=.,0,b.perCap),a.Act))*(1-d.ProjectedFmap)*ifn(b.Eligibles =.,1,b.Eligibles) as AffectField
   from PT_Missing_&meg._&svc as a 
   inner join input_&meg._&svc as b
     on a.Date = b.mos
   inner join famp_&meg._&svc as d
     on a.Date = d.MOS
   where Date between &startMon and &mon;
 quit; 
%mend;

/*%PT_patching (meg=1271, svc=671);*/


%macro ETL;
   %local name dt;
   %let name = final;
   %if %sysfunc(exist(&name)) %then %do;
     proc sql;
	  drop table &name;
	   create table &name
       (
        FcMeg num,
        FcSvc num,
        ServiceMonth num format=6.,
        FundType char(1),
        AffectField num
       );
	 quit;
	%end;
	%else %do;
   proc sql;
	  create table &name
       (
        FcMeg num,
        FcSvc num,
        ServiceMonth num format=6.,
        FundType char(1),
        AffectField num
       );
	 quit;


   %end;
   %let dsid = %sysfunc(open(cells));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
     
       %PT_patching (meg=&meg, svc=&svc , type = &type);
	   proc sql;
	     insert into &name (FcMeg,FcSvc,ServiceMonth,FundType,AffectField)
		 select *
		 from patch_&meg._&svc;
	   quit;
     %end;
   %let rc = %sysfunc(close(&dsid));
   
   %let dt=%sysfunc(today(),date9.)_%sysfunc(compress(%sysfunc(time(),time6),:));
   Proc Export data=&name                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
	outfile="Q:\ForecastOFM\Production\NwCycle&cycle._02\ForecastPTFmap\Premium_all_updated_Final_&dt..xlsx"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
	DBMS=EXCEL2010 REPLACE;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
	SHEET="Step";                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
 Run;            
%mend ETL;

%ETL;




 libname FP1 clear;
 libname FP2 clear;
 libname FP3 clear;
 libname FPAll clear; 
 libname PT clear;
