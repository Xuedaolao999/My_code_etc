dm 'log' clear;
option mprint mlogic;
%let cycle = 2117;
libname wk "Q:\ForecastOFM\Production\NwCycle2117_02\ForecastPTFmap\WorkingProgs";
libname prod1 "Q:\ForecastOFM\Production\NwCycle&cycle._01\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle\Version A\Primary Trend";
libname prod2 "Q:\ForecastOFM\Production\NwCycle&cycle._02\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle\Version A\Primary Trend";
libname prod3 "Q:\ForecastOFM\Production\NwCycle&cycle._03\ForecastPTFmap\Forecast Process Specific Files\Cycle &cycle\Version A\Primary Trend";

libname total(prod1, prod2, prod3);


/* test sets for the cells that needed COVID19 step*/
%let loc = %str(Q:\ForecastOFM\Production\NwCycle2117_02\ForecastPTFmap\WorkingProgs);
%let cell_list = step covid19 meg svc_02112021_1222pm.xlsx;

PROC IMPORT OUT= cell_src DATAFILE= "&loc.\&cell_list" DBMS=EXCEL REPLACE ;
  GETNAMES=YES;
  MIXED=NO;
  SCANTEXT=YES;
  USEDATE=YES;
  SCANTIME=YES;
RUN;


data cell_list;
  set CELL_SRC ; 
/*  where ProposeCelltype = "S";*/
run; 


data cell_check;
  set cell_list;
/*  WHERE ForMeg = "1280" and ForSvc = "221";*/
  keep ForMeg ForSvc ProposeCelltype;
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

proc sql;
  create table cell_no_pt 
  (
   ForecastMeg varchar(4),
   ForecastSvc varchar(3),
   Celltype varchar(1),
   reason varchar(10)
  );
quit;

%macro exits_cells;
   
   %let dsid = %sysfunc(open(cell_check));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
     %PUT NOTE:  I am in cell >>>>>>(&ForMeg, &ForSvc,&ProposeCelltype)<<<<< ;
	 %if %upcase(&ProposeCelltype) = L %then %do;
	   %put NOTE: I AM A LARGE CELL;
	   %if %sysfunc(exist(Total.R_&ForMeg._&ForSvc._newmodel_2117_1)) %then %do;
         %put 	NOTE: FILE  EXISTS;
		 proc sql;
	       select count(*) into: ct
		   from Total.R_&ForMeg._&ForSvc._newmodel_2117_1;
	     quit;
	     %if &ct=0 %then %do;
	       proc sql;
		     insert into cell_no_pt(ForecastMeg,ForecastSvc,Celltype, reason)
		     values("&ForMeg","&ForSvc","&ProposeCelltype","empty");
		  quit;
	      %END;


	   %end;
	   %else %do; 
        %put 	NOTE: FILE NOT EXISTS;
		proc sql;
		     insert into cell_no_pt(ForecastMeg,ForecastSvc,Celltype, reason)
		     values("&ForMeg","&ForSvc","&ProposeCelltype","non_exist");
		  quit;
	   %end;
	%END; * end of large cell;

%if %upcase(&ProposeCelltype) = S %then %do;
	   %put NOTE: i am a small cell;
	   %if %sysfunc(exist(total.Ucmsts_&ForMeg._&ForSvc.)) %then %do;
         %put 	NOTE: FILE  EXISTS;

		 proc sql;
	       select count(*) into: ct
		   from total.Ucmsts_&ForMeg._&ForSvc.;
	     quit;
	     %if &ct=0 %then %do;
	       proc sql;
		     insert into cell_no_pt(ForecastMeg,ForecastSvc,Celltype, reason)
		     values("&ForMeg","&ForSvc","&ProposeCelltype","empty");
		  quit;
	      %END;


	   %end;
	   %else %do; 
        %put 	NOTE: FILE NOT EXISTS;
		proc sql;
		     insert into cell_no_pt(ForecastMeg,ForecastSvc,Celltype, reason)
		     values("&ForMeg","&ForSvc","&ProposeCelltype","non_exist");
		  quit;
	   %end;
	%END;
	   




	
	 
	 
   %end;
  %let rc = %sysfunc(close(&dsid));
%mend;

/* find the cells have not 	PT*/
%exits_cells;


/*applid the COVID19 step and create the step data */
%macro covid_step(category, service, LS_flag, T_Short, T_Long, T_Manual, Last_day);

	/* Prelim data driven model */

	proc sql;
		create table snark as
			select distinct
				mos_counter,
				percap
			from wk.covid_step_actuals
			where ForMeg = &category and ForSvc = &service
				and mos_counter between 15 and 20
	;quit;
		
	%if %upcase(&LS_Flag.) = L %then %do;
		proc sql;
			create table boojum as 
				select distinct
					date,
					case 
						when date = '01MAR2020'd then 15
						when date = '01APR2020'd then 16
						when date = '01MAY2020'd then 17
						when date = '01JUN2020'd then 18
						when date = '01JUL2020'd then 19
						when date = '01AUG2020'd then 20
					end as mos_cnt,
					STPriorPercap,
					pred as predict
				from 
					total.R_&category._&service._newmodel_2117_1
		;quit;
	%end;

	%if %upcase(&LS_flag.) = S %then %do;
		proc sql;
			create table boojum as 
				select distinct
					date,
					case 
						when date = '01MAR2020'd then 15
						when date = '01APR2020'd then 16
						when date = '01MAY2020'd then 17
						when date = '01JUN2020'd then 18
						when date = '01JUL2020'd then 19
						when date = '01AUG2020'd then 20
					end as mos_cnt,
					STPriorPercap,
					predict
				from 
					total.Ucmsts_&category._&service.
		;quit;
	%end;
	proc sql;
		create table whozit as
			select distinct
				a.date,	
				a.predict,					
				coalesce(b.Percap,a.STPriorPercap) as actual,
				coalesce(b.Percap,a.STPriorPercap) /(a.predict+.0000001)as ratio

			from (boojum as a left join snark as b
				on a.mos_cnt = b.mos_counter) 
	;quit;
    data whatzit;
	   set whozit;
	   if eof1=0 then 
           set whozit (firstobs=2 keep=ratio rename=(ratio=ratio_lead1)) end=eof1; 
       else ratio_lead1=.;	   
	   if eof2=0 then 
           set whozit (firstobs=3 keep=ratio rename=(ratio=ratio_lead2)) end=eof2; 
       else ratio_lead2=.;
	run;

	data covid_&service._&category. (keep = Date actual predict covid step F Fmar Fapr Fmay Fjun Fjul Faug Fsep T_Return);
		set whatzit;
		retain Fjun Fjul Fmar Fapr Fmay Faug Fsep T_Return; 
		format T_return date9.;
		if date <= '01FEB2020'd then do;
			F = 1; 
			Fapr=1; Fmar=1; Fmay=1; Fjun = 1; Fjul=1; Faug = 1;
		end;
		if date = '01MAR2020'd  then do;
			F = actual / predict;
			Fmar = F;
		end;
		if date = '01APR2020'd then do;
			F = actual / predict;
			Fapr = F;
		end;
		if date = '01MAY2020'd then do;
			F = actual / predict;
			Fmay = F;
		end;
		if date = '01JUN2020'd then do;
			F = actual / predict;
			Fjun = F;
		end;
		
		if %upcase(&Last_Day.) = "JUL" then do;
		    if date = '01JUL2020'd then do;
			    F = actual / predict;
			    Fjul = F;
				Faug = ratio_lead1;
				Fsep = ratio_lead2;
		    end;
		    if &service. = 551 then Fjun = Fjul;

			if max(abs(1-Fmar)+abs(1-Fapr),abs(1-Fapr)+abs(1-Fmay)) / (abs(1-Fjun) + abs(1-FJul)+.00001)  < 2 
				then T_return = &T_Long.; else T_return = &T_Short.;

			/*if abs(1-Faug)+abs(1-Fsep) > abs(1-Fjun)+abs(1-Fjul) then T_return = &T_Long.;*/

			if (Fmar>1 and Fapr<1) or (Fmar<1 and Fapr>1) or (Fapr>1 and Fmay<1) or (Fapr<1 and Fmay>1) 
				then T_return = '01SEP2020'd; 

			if &T_Manual. > '01JAN2020'd then T_Return = &T_Manual.;

			if date >= '01AUG2020'd and date < T_Return then do;
				F = .5*(Fjun+Fjul) + ((1-.5*(Fjun+Fjul))/(T_Return-'01JUL2020'd))*(date - '01JUL2020'd);
			end;
        end;
        else do;
		    if date = '01JUL2020'd then do;
			    F = actual / predict;
			    Fjul = F;
		    end;
		    if date = '01Aug2020'd then do;
			    F = actual / predict;
			    Faug = F;
				Fsep = ratio_lead1;
		    end;
		    if &service. = 551 then Fjun = Fjul;

			if max(abs(1-Fmar)+abs(1-Fapr),abs(1-Fapr)+abs(1-Fmay)) / (abs(1-Fjul) + abs(1-Faug)+.00001)  < 2 
				then T_return = &T_Long.; else T_return = &T_Short.; 

			if abs(1-Faug)+abs(1-Fsep) > abs(1-Fjun)+abs(1-Fjul) then T_return = &T_Long.;

			if (Fmar>1 and Fapr<1) or (Fmar<1 and Fapr>1) or (Fapr>1 and Fmay<1) or (Fapr<1 and Fmay>1) 
				then T_return = '01SEP2020'd; 

			if &T_Manual. > '01JAN2020'd then T_Return = &T_Manual.;

			if date >= '01SEP2020'd and date < T_Return then do;
				F = .5*(Fjul+Faug) + ((1-.5*(Fjul+Faug))/(T_Return-'01AUG2020'd))*(date - '01AUG2020'd);
			end;

        end;
	
		if date >= T_Return  then do;
				F = 1; 
			end;
			covid = predict*F;
			step = covid - predict;
		run;

	proc sql;
      insert into cov_19_step(Forecastmeg,ForecastSvc,Date,PT,PT_w_cov,step)
      select "&category","&service",date,predict,covid,step
      from covid_&service._&category;
    quit;

%mend;

proc sql;
 create table cell_list_new as 
 select a.*
 from cell_list as a 
 inner join (select ForMeg, ForSvc,ProposeCelltype
             from  cell_list 
			 except 
			 select ForecastMeg, ForecastSvc,Celltype
			 from cell_no_pt) as b
  on a.ForMeg = b.ForMeg and a.ForSvc = b.ForSvc and a.ProposeCelltype = b.ProposeCelltype;
quit; 


/*loop through all the cells that needed the COVID19 step */
/*dm 'log' clear;*/
%macro loop_cells;
   
   %let dsid = %sysfunc(open(cell_list_new));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
     %PUT NOTE:  I am in cell >>>>>>(&ForMeg, &ForSvc,&ProposeCelltype,&Return_Short,&Return_Long,&Return_Override,&Last_Day)<<<<< ;
	 %covid_step(&ForMeg,&ForSvc,&ProposeCelltype,&Return_Short,&Return_Long,&Return_Override,&Last_Day);
   %end;
  %let rc = %sysfunc(close(&dsid));
%mend;

%loop_cells;

/*dm 'log' clear;*/
/*%covid_step(1211,211,S,'01DEC2020'd,'01DEC2021'd,"16DEC1770"d, 'aug');*/
/*%covid_step(1221,773,L,'01DEC2020'd,'01DEC2021'd,"16DEC1770"d, jul);*/




libname total clear;
libname prod1 clear;
libname prod2 clear;
libname prod3 clear;
libname wk clear;

%let dt=%sysfunc(today(),date9.)_%sysfunc(compress(%sysfunc(time(),time6),:));
%put &dt;

libname dest "Q:\ForecastExt\Feb 21 Forecast\Steps";
 
data dest.cov_19_step_&dt;
 set cov_19_step;
 run;

data dest.cov_step_empty_PT_&dt;
   set cell_no_pt;
run; 
libname dest clear;

/*
proc print data = cov_19_step ;
run; 
*/
