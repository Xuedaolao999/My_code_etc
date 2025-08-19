/* this is to checking the MedForecastTracking.xls */
dm 'log' clear;

/* Define the forecasting window */
%let FromDt = 202407;
%let ToDt = 202706;
%let cycle = 2517;

/*Create the copy of the MaPredicted in the work library*/
libname Checking "Q:\ForecastOFM\Production\NwCycle&cycle._01\Data\SourceIn";

Data Mapredictedpercap;
  set checking.Mapredictedpercap_31jan2025_1015;
run; 

libname Checking clear;



 
/* prepare the time window to check */
%macro CreatContMonth(start = &FromDt,end = &ToDt);
 data mon;
   first_of_month = mdy(%substr(&start,5,2),1,%substr(&start,1,4));
   do until (first_of_month > mdy(%substr(&end,5,2),1,%substr(&end,1,4)));
      output;
      first_of_month = intnx('month',first_of_month,1);
      end;
 run;


 data ConMonth;
   set mon;
   mon = month(first_of_month);
   if mon< = 9 then do;
     mon1 = '0'||trim(left(mon));
   end;
   else mon1 = mon;
   yr = year(first_of_month);
   newMos= input(yr||trim(left(mon1)),20.);
   drop mon yr mon1 first_of_month;
 run;

 proc datasets lib= work;
  delete mon;
 quit;
%mend CreatContMonth;




/* data Mapredictedpercap */

proc sql noprint;
 select distinct ForecastMeg into :Gmeg separated BY ','
 from Mapredictedpercap;
 select distinct ForecastSvc into :GSvc separated by ','
 from Mapredictedpercap;
quit;



%macro CheckingMissingPerCap (Meg = 1280,Svc = 223, CellType = S);
 
 %local cnt cnt1 i;
 proc sql noprint;
  
    select count(1) into  :cnt 
    from  Mapredictedpercap 
    where forecastMeg = "&Meg" and upcase(forecastSvc) = %upcase("&Svc")
          and upcase(PrimaryTrendCellType) = %upcase("&CellType");
  quit;
  %if %eval(&cnt>=1) %then %do;
   proc sql noprint;
     create table test as 
     select distinct a.forecastMeg,a.forecastSvc,PrimaryTrendCellType,a.MaPredictedPercap,a.ServiceMonth, b.NewMos
     from Mapredictedpercap (where = (forecastMeg = "&Meg" and upcase(forecastSvc) = %upcase("&Svc") and upcase(PrimaryTrendCellType) = %upcase("&CellType")))as a 
     right join ConMonth as b 
       on a.ServiceMonth = b.newMos
     where a.MaPredictedPercap is missing
     order by a.ServiceMonth;
   quit;
  
 
  data _null_;
    set test nobs=nobs;
	call symput('cnt1',nobs);
    stop;
  run; 
  %end;

  %if %eval(&cnt1>=1) %then %do;
    proc sql noprint;
      select distinct NewMos into :MissingMonth separated by ","
	  from test;
    
/*	  %put NOTE: MissingMonth IS >>>>>>>>>>>>>>&MissingMonth;*/
/*	  %RETURN; */
	%let i = 1;
    %let TheMissingMonth = %scan(%bquote(&MissingMonth), &i,%str(,));
	%do %while (%length(&TheMissingMonth)>0);
       insert into MissingSet (Meg,svc,type, month)
       values ("&Meg", "&svc","&cellType",&TheMissingMonth); 
	   %let i = %eval(&i+1);
       %let TheMissingMonth = %scan(%bquote(&MissingMonth), &i,%str(,));
	%end;
    quit;
 %end;
%mend;

%*%CheckingMissingPerCap;
    

%macro final(Type = S, from = &FromDt, to = &ToDt);
  proc sql;
  create table MissingSet  (Meg char(4),
                            svc char(3),
							type varchar(1),
							month int
						  );
                            
  quit;
  %local mgp svc i j;
  %CreatContMonth(start = &from,end = &to);
  %let i = 1;
  %let mgp = %scan(%bquote(&Gmeg),&i,%str(,));
  %do %while (%length(&mgp)>0);
    %let j = 1;
	%let svc = %scan(%bquote(&GSvc),&j,%str(,));
    %do %while(%length(&svc)>0);
	%CheckingMissingPerCap (Meg = &mgp,Svc = &svc, CellType = &type);
     %let j = %eval(&j+1);
	 %let svc = %scan(%bquote(&GSvc),&j,%str(,));
	%end;
   %let i = %eval(&i+1);
   %let mgp = %scan(%bquote(&Gmeg),&i,%str(,));
  %end;
%mend final;

%final(Type = S, from = &FromDt, to = &ToDt);

/* check the result */
proc print data = MissingSet;
run;   



proc sql;
  create table MissingMegSvc as 
  select distinct Meg, Svc 
  from MissingSet
  
  order by 2,1;
quit ;

proc print data = MissingMegSvc;
run; 

/*
proc sql;
  drop table MissingSet;
quit; 

*/
