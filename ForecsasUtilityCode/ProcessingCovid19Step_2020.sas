dm 'log' clear;

%let cycle = 2112;
libname prod1 "Q:\ForecastOFM\Production\NwCycle&cycle._01\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle\Version A\Primary Trend";
libname prod2 "Q:\ForecastOFM\Production\NwCycle&cycle._02\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle\Version A\Primary Trend";
libname prod3 "Q:\ForecastOFM\Production\NwCycle&cycle._03\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle\Version A\Primary Trend";

libname total(prod1, prod2, prod3);



/*Create the copy of the MaPredicted in the work library*/
%let cycle = 2112;
%let thiscycle = &cycle;
/*%let to = '01Jun2020'd; the time when back to the normal*/
libname Checking "Q:\ForecastOFM\Production\NwCycle&cycle._01\Data\SourceIn";

Data Mapredictedpercap org_Mapredictedpercap;
  set checking.Mapredictedpercap_30sep2020_1134;
  date =  input(put(ServiceMonth,z6.),yymmn6.);
  format date monyy7.;
run; 


proc sql;
  create table cov_19_step 
  (
   ForecastMeg varchar(4),
   ForecastSvc varchar(3),
   Date num format=MONYY7.,
   PT numeric,
   PT_w_cov numeric,
   step numeric
  );
quit;

/*applid the COVID19 step and create the step data */
/* 
Macro covid_step applied the covid step at the MEG-Service cell level. 
Input paraleters:
	Category and service: Obvious.
	T_Min: Date of low-point
	F_Min: Low-point discount expressed as a fraction between 0 and 1. 
	T_Return: Date of return to full utilization.

	Date parameters should be entered in format '01MMMYYYY'd
*/

%macro covid_step_L(category, service, F_min, T_min, T_return);

   data covid_&service._&category. (keep = Date Pred covid step F);
			set Total.R_&category._&service._newmodel_2112_1 ;
			if date <= '01FEB2020'd or date >= &T_Return. then do;
				F = 1; 
			end;
			if date >= '01MAR2020'd  and date < &T_Min. then do;
				F = &F_min. + ((1-&F_min.)/( &T_Min. - '01FEB2020'd ))*(&T_Min. - date);
			end;
			if date = &T_min. then do;
				F = &F_Min. ;
			end;
			if date > &T_Min. and date < &T_Return. then do;
				F = &F_min. + ((1-&F_min.)/(&T_Return.-&T_Min.))*(date - &T_Min.);	
			end;
			covid = pred*F;
			step = covid-pred;	
		run;

	 
proc sql;
  create table Covid19_step_&category._&service  as
  select &category as ForecastMeg,  &service as ForecastSvc, a.*
  from covid_&service._&category. as a 
  where a.date between '01Feb2020'd and &T_Return
  order by date;

  insert into cov_19_step (ForecastMeg,ForecastSvc,Date,PT,PT_w_cov,step )
  select put(ForecastMeg,4.),put(ForecastSvc,3.),Date,Pred,covid,step
  from Covid19_step_&category._&service;

  update Mapredictedpercap as a 
    set MaPredictedPercap = (select covid
	            from covid_&service._&category. as b
				where a.date = b.date
                  )
  where a.date between '01FEB2020'd and &T_Return 
        and a.ForecastMeg ="&category"  and a.ForecastSvc= "&service";

  
quit;


%mend;

%macro covid_step_S(category, service, F_min, T_min, T_return);
	
	/* Small Cell */
		
		data covid_&service._&category. (keep = Date Predict covid step F);
			set total.Ucmsts_&category._&service. ;
			if date <= '01FEB2020'd or date >= &T_Return. then do;
				F = 1; 
			end;
			if date >= '01MAR2020'd  and date < &T_Min. then do;
				F = &F_min. + ((1-&F_min.)/( &T_Min. - '01FEB2020'd ))*(&T_Min. - date);
			end;
			if date = &T_min. then do;
				F = &F_Min. ;
			end;
			if date > &T_Min. and date < &T_Return. then do;
				F = &F_min. + ((1-&F_min.)/(&T_Return.-&T_Min.))*(date - &T_Min.);	
			end;
			covid = predict*F;
			step = covid-predict;	
		run;

	proc sql;
     create table Covid19_step_&category._&service  as
     select &category as ForecastMeg,  &service as ForecastSvc, a.*
  	 from covid_&service._&category. as a 
     where a.date between '01Feb2020'd and &T_Return
     order by date;

	 insert into cov_19_step (ForecastMeg,ForecastSvc,Date,PT,PT_w_cov,step )
     select put(ForecastMeg,4.),put(ForecastSvc,3.),Date,Predict,covid,step
     from Covid19_step_&category._&service;

     update Mapredictedpercap as a 
      set MaPredictedPercap = (select covid
	            from covid_&service._&category. as b
				where a.date = b.date
                  )
   where a.date between '01FEB2020'd and &T_Return 
        and a.ForecastMeg ="&category"  and a.ForecastSvc= "&service";

  
quit;
%mend;

/*%covid_step_S(1222,221,.786,'01APR2020'd, '01SEP2020'd);*/


/* test sets for the cells that needed COVID19 step*/
%let loc = %str(Q:\ForecastOFM\Production\NwCycle2112_02\ForecastPTFmap\WorkingProgs);
%let cell_list = Covid19_utilization_adj_2020_new.xlsx;

PROC IMPORT OUT= cell_src DATAFILE= "&loc.\&cell_list" DBMS=EXCEL REPLACE ;
  GETNAMES=YES;
  MIXED=NO;
  SCANTEXT=YES;
  USEDATE=YES;
  SCANTIME=YES;
RUN;

data cell_src;
 set cell_src;
  StartDate_new =  input(put(StartDate,z6.),yymmn6.);
  Middate_new = input(put(Middate,z6.),yymmn6.);
  EndDate_new =input(put(EndDate,z6.),yymmn6.);
  format StartDate_new Middate_new   EndDate_new monyy7.;
run; 



data cell_list;
  set cell_src ;
/*  where ForSvc = "211" and  ForMeg =  "1222" ;*/
run; 

/*proc print data = cell_list;*/
/*  var ForSvc ForMeg;*/
/*run; */

/*
%if %sysfunc(exist(work.stepData)) %then %do;
	  %put NOTE: the table work.stepData exists!;
	%end;
	%else %do;*/
/*loop through all the cells that needed the COVID19 step */
%macro loop_cells;
   
   %let dsid = %sysfunc(open(cell_list));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
     %PUT NOTE:  I am in cell >>>>>>(&ForMeg, &ForSvc,&StartDate_new,&Middate_new,&EndDate_new,&PctRatio)<<<<< ;
     %if %sysfunc(exist(Total.R_&ForMeg._&ForSvc._newmodel_2112_1)) %then %do;
     %covid_step_L(&ForMeg,&ForSvc,&PctRatio,&Middate_new, &EndDate_new);
       %put >>>>>>>>>>>>>>>>>>>>>>I am lage;
      %end; 
	 %else %do;
	  %covid_step_S(&ForMeg,&ForSvc,&PctRatio,&Middate_new, &EndDate_new);
       %put +++++++++++++++++++++ i am small;
	 %end;
   %end;
  %let rc = %sysfunc(close(&dsid));
%mend;

%loop_cells;

libname total clear;
libname prod1 clear;
libname prod2 clear;
libname prod3 clear;
libname Checking clear;

%let dt=%sysfunc(today(),date9.)_%sysfunc(compress(%sysfunc(time(),time6),:));
/*%put &dt;*/




libname dest "Q:\ForecastExt\Oct 20 Forecast\Steps\Covid19";
 
data dest.cov_19_step_&dt;
/*set Mapredictedpercap;*/
 set cov_19_step;
run;
libname dest clear;

