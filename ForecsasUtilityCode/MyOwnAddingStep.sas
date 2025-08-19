/* ****************************************************************
    Achieved: can produce the per cap with step applied 
    progress: 1: calculate the FMAP with step: done
              2: plot the step: partly done, but need to work more to complete for all the cells
              3: polish the codes and improve it 
             

*/

dm 'log' clear;
%let _timer_start = %sysfunc(datetime());
Proc Format;
picture mydtfmt
  low-high = '%0m-%0d-%Y @ %0I.%0M %p' (datatype=datetime);
Run;
Proc PrintTo 
LOG="I:\MyAddingStepLog_%unquote(%sysfunc(datetime(),mydtfmt.)).txt" ;
Run;
option mprint mlogic FULLSTIMER;

%let cycle = 1924;
%let ReleaseVerLetter = D04;
%let ReleaseVerLetterNoStep = a03;
%put %upcase("&ReleaseVerLetter");

%let location = %str(I:\MyDocu\ForecastDocu\_SubVersion);
%let stepFile = ForecastSteps - D03 Final.xlsx;
%let stepFile = ForecastSteps - D02 final.xlsx;
%let stepFile = ForecastSteps - D04 working.xlsx;

/* create a function to input string, not done yet, */

/*step 1, input the PT data without any step added*/
%let AfrsOdbcFileDsn= &location.\OFMForecastProduction.dsn;
LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=dbo;

proc sql;
 create table PT_data as 
 select *
 from Forecast.trackingDetail_history
 where ThisCycle ="&cycle" and ReleaseVerLetter = "&ReleaseVerLetterNoStep";

 create table PT_data_no_step as 
 select * 
 from PT_data;
quit; 

libname Forecast clear;


/* step 2: input the step data and copy to work library  */
libname xs XLSX "&location.\&stepFile";

proc copy in=xs out=work;
run; 
libname xs clear;

/* obtaining the steps */

%let megLst=_1211	_1212	_1221	_1222	_1230	_1251	_1252	_1253	_1261	_1262	_1271	_1272	
            _1280	_1290	_1330	_1350	_1470	_1480	_1495	_1499	_1500	_1621	_1622	_1640	
            _1675	_1676	_1677	_1720	_1861	_1862	_1910	_1950	_1960	_1974	_1998;

%let svcLst = _101	_211	_221	_223	_235	_290	_295	_310	_333	_336	_343	_350	
             _371	_375	_379	_385	_410	_413	_421	_422	_450	_453	_551	_571	
             _610	_620	_630	_635	_661	_671	_680	_691	_692	_731	_740	_751	
            _761	_771	_772	_773	_775	_776	_777	_791;


/*Find the MEGs and SVCsaffected by a given step SID */
proc transpose data = MegMethodMatch out =Sid_Meg_temp (drop = _LABEL_ rename = (COL1 = Value)) name = Meg;
  by StepID;
  var &megLst;

run;

proc transpose data = SvcMethodMatch out =Sid_Svc_temp (drop = _LABEL_ rename = (COL1 = Value)) name = Svc;
  by StepID;
  var &svcLst;

run;

proc sql noprint;
  create table Sid_Meg as
  select StepID,compress(tranwrd(Meg,"_","")) length =10 as Meg,Value
  from Sid_Meg_temp
  where upcase(value)=upcase("x");

  create table Sid_Svc as
  select StepID,compress(tranwrd(Svc,"_","")) length =10 as Svc,Value
  from Sid_Svc_temp
  where upcase(value)=upcase("x");

  create table Sid_cell as 
  select distinct a.StepID,a.Meg,b.Svc, c.stepOrder, d.Fact_Unit
  from Sid_Meg as a 
  inner join Sid_svc as b
    on a.StepID = b.StepID
  inner join step as c 
    on a.stepId = c.stepID
  inner join TabMetaData as d 
    on a.stepId = d.StepId
  order by c.stepOrder;
quit; 


/* For a given cell, apply all the steps to PT */
/* create table to store all the steps data for all cells*/
%macro ETL(ForecastMeg=, ForecastSvc =, excludeStep =  );
    %local Meg Svc StepID StepOrder Fact_Unit nvar ;
	%if %sysfunc(exist(work.stepData)) %then %do;
	  %put NOTE: the table work.stepData exists!;
	%end;
	%else %do;
      proc sql;
       create table stepData (StepID varchar(5),
                           Formeg varchar(4),
                           ForSvc varchar(3),
                           MonthOfService varchar(6),
			               StepPerCap numeric
						   );

  
     quit; 

	%end;
    proc sql noprint;
     create table patch as 
     select *
     from sid_cell
	 %if &ForecastMeg= and &ForecastSvc = %then %do;
	 %put NOTE: I am here ;
	  %end;
	 %else %do;
	 %put NOTE: I am here BELOW===================;
     where meg = "&ForecastMeg" and svc = "&ForecastSvc"
	 %end;
     order by Meg, Svc, StepOrder;

   %if &excludeStep ^= %then %do;
   %put I am goint to delete some steps &excludeStep;

    delete from patch
	where StepID in( &excludeStep);
	%end;
  quit; 
   
   %let dsid = %sysfunc(open(patch));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
    %put NOTE: StepID is ++++++++++++++&StepID;
    %PUT NOTE:  I am in cell >>>>>>(&Meg, &svc,&StepID)<<<<< ;
    
    %PUT NOTE: StepOrder IS ++++++++++++++++++&StepOrder;
	%PUT NOTE: Fact_Unit IS ++++++++++++&Fact_Unit;
	 
	proc sql noprint;
	  select count(1) into: CellApplied
	  from stepData
	  where Formeg = "&Meg" and ForSvc = "&Svc" and StepID = "&StepID";
	quit;
    
   /* if a step is already applied in a given cell, this step will not be applied again */
	%if &CellApplied>=1 %then %goto leave;

	

	%let dat = &StepID;
	%let dat= %sysfunc(cat(&dat,1));
	%put dat is +++++++++++++&dat;

	proc sql noprint;
	  select nvar into:nvar
	  from dictionary.tables 
	  where libname = "WORK" and memname=%upcase("&dat");
	quit; 
    
	%if %upcase(&Fact_Unit) = AMT %then %do;
    /* amount based 	 */

	  %put NOTE: I am in amount ++++++++++++++++++++++++;
	  proc sql noprint;
	    create table stepInput1 as 
	    select put(FcMeg,4.)as FcMeg, put(FcSvc,3.) as FcSvc, ServiceMonth, sum(AffectField) as AffectField
		from &dat
        where FcMeg = &Meg and FcSvc = &Svc
		group by FcMeg, FcSvc, ServiceMonth
		order by ServiceMonth;
        
		%if &nvar>4 %then %do;
		create table tmp as 
		select distinct a.ForecastMeg, a.ForecastSvc, a.MonthOfService, ROUND((a.PerCap+b.AffectField/a.Eligible),0.0001) as newPerCap,
               ROUND(b.AffectField/a.Eligible,0.0001) as StepPerCap, 
               round(a.total+b.AffectField,0.0001) as newTotal, round(a.Federal+coalesce(c.AffectField,0),0.0001) as newFederal,
			   round(a.State+coalesce(d.AffectField,0),0.0001) as newState, round(a.Local+coalesce(e.AffectField,0),0.0001) as newlocal
        from PT_data as a 
        inner join stepInput1 as b
         on a.ForecastMeg = b.FcMeg and a.ForecastSvc = b.FcSvc
            and input(a.MonthOfService,6.) = b.ServiceMonth
         left join &dat as c 
		   on b.FcMeg = put(c.FcMeg,4.) and b.FcSvc = put(c.FcSvc,3.) and c.FundType = "F" and b.ServiceMonth = c.ServiceMonth
		left join &dat as d 
		   on b.FcMeg = put(d.FcMeg,4.) and b.FcSvc = put(d.FcSvc,3.) and d.FundType = "G" and b.ServiceMonth = d.ServiceMonth
		left join &dat as e
		   on b.FcMeg = put(e.FcMeg,4.) and b.FcSvc = put(e.FcSvc,3.) and e.FundType = "L" and b.ServiceMonth = e.ServiceMonth

         order by a.MonthOfService;
        %end;
		%else %do;
          create table tmp as 
		select distinct a.ForecastMeg, a.ForecastSvc, a.MonthOfService, ROUND((a.PerCap+b.AffectField/a.Eligible),0.0001) as newPerCap,
               ROUND(b.AffectField/a.Eligible,0.0001) as StepPerCap, 
               round(a.total+b.AffectField,0.0001) as newTotal, round(a.Federal+(a.Federal/a.total)*c.AffectField,0.0001) as newFederal,
			   round(a.state+(a.state/a.total)*c.AffectField,0.0001) as newState, round(a.local+(a.local/a.total)*c.AffectField,0.0001) as newLocal
        from PT_data as a 
        inner join stepInput1 as b
         on a.ForecastMeg = b.FcMeg and a.ForecastSvc = b.FcSvc
            and input(a.MonthOfService,6.) = b.ServiceMonth
         inner join &dat as c 
		   on b.FcMeg = put(c.FcMeg,4.) and b.FcSvc = put(c.FcSvc,3.) and b.ServiceMonth = c.ServiceMonth
         order by a.MonthOfService;

		%end;
     /* populate the table that stores the step induced percap amount       */
       create table popStep as 
	   select distinct "&StepID" as StepID, ForecastMeg, ForecastSvc, MonthOfService,StepPerCap
	   from tmp as a
       where not exists (select 1 
                         from stepData 
                         where upcase(StepID)=%upcase("&StepID")
						       and Formeg = a.ForecastMeg and ForSvc = a.ForecastSvc 
                         );

        insert into stepData (StepID,ForMeg,ForSvc,MonthOfService,StepPerCap)
		select distinct "&StepID" as StepID, ForecastMeg, ForecastSvc, MonthOfService,StepPerCap
		from popStep;
		

       quit;
       
     
	%end;
	%else %do;
    /* rate based   */
	%put NOTE: I am in rate ++++++++++++++++++++++++++++++++++++++;
    
	
    
	%if &nvar>=4 %then %do;
	  %put NOTE: i am in rate with 4 variables in step ++++++++++++++++++++++++++++++++++++++++;
	  proc sql noprint;
	     create table tmp as 
         select distinct a.ForecastMeg, a.ForecastSvc, a.MonthOfService, round(a.PerCap*b.AffectField, 0.0001) as newPerCap,
		        round(a.PerCap*(b.AffectField-1), 0.0001) as StepPerCap,
                round(total*b.AffectField,0.0001) as newTotal,round(Federal*b.AffectField,0.0001) as newFederal,
				round(a.State*b.AffectField,0.0001) as newState, round(a.local*b.AffectField,0.0001) as newlocal
         from PT_data (where =(ForecastMeg = "&Meg" and ForecastSvc = "&Svc")) as a 
         inner join &dat as b
           on input(a.MonthOfService,6.) = b.ServiceMonth and a.ForecastMeg = put(b.FcMeg,4.) and a.ForecastSvc = put(b.FcSvc,3.)
         order by a.MonthOfService;
       
		/* populate the table that stores the step induced percap amount       */
       create table popStep as 
	   select distinct "&StepID" as StepID, ForecastMeg, ForecastSvc, MonthOfService,StepPerCap
	   from tmp as a 
        where not exists (select 1 
                         from stepData 
                         where upcase(StepID)=%upcase("&StepID")
						       and Formeg = a.ForecastMeg and ForSvc = a.ForecastSvc 
                         );

        insert into stepData (StepID,ForMeg,ForSvc,MonthOfService,StepPerCap)
		select distinct "&StepID" as StepID, ForecastMeg, ForecastSvc, MonthOfService,StepPerCap
		from popStep;
		

	   quit;

	%end;
    %else %do;
	   %put NOTE: i am in rate with less than 4 variables in step ++++++++++++++++++++++++++++++++++++++++;
	   proc sql noprint;
	     create table tmp as 
         select distinct a.ForecastMeg, a.ForecastSvc, a.MonthOfService, round(a.PerCap*b.AffectField, 0.0001) as newPerCap,
		        round(a.PerCap*(b.AffectField-1), 0.0001) as StepPerCap,round(total*b.AffectField,0.0001) as newTotal,round(Federal*b.AffectField,0.0001) as newFederal,
				round(a.State*b.AffectField,0.0001) as newState,round(a.Local*b.AffectField,0.0001) as newLocal
         from PT_data (where =(ForecastMeg = "&Meg" and ForecastSvc = "&Svc")) as a 
         inner join &dat as b
           on input(a.MonthOfService,6.) = b.ServiceMonth
         order by a.MonthOfService;
       
		 /* populate the table that stores the step induced percap amount       */
        /* populate the table that stores the step induced percap amount       */
       create table popStep as 
	   select distinct "&StepID" as StepID, ForecastMeg, ForecastSvc, MonthOfService,StepPerCap
	   from tmp as a 
        where not exists (select 1 
                         from stepData 
                         where upcase(StepID)=%upcase("&StepID") 
						       and Formeg = a.ForecastMeg and ForSvc = a.ForecastSvc 
                        /* i have to adde the meg and svc to above condidtion I am here to proceed */
                         );

        insert into stepData (StepID,ForMeg,ForSvc,MonthOfService,StepPerCap)
		select distinct "&StepID" as StepID, ForecastMeg, ForecastSvc, MonthOfService,StepPerCap
		from popStep;
		

       quit;
     %end;
	%end;
    
	
	proc sql noprint;
      update PT_data as a 
        set PerCap = ( select newPerCap
	                   from tmp as b
				       where a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc and a.MonthOfService = b.MonthOfService
				  )
	     where a.ForecastMeg = "&Meg" and a.ForecastSvc = "&Svc" and a.MonthOfService in (select MonthOfService from tmp);
       
	  update PT_data as a
        set Total = ( select newTotal
	                   from tmp as b
				       where a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc and a.MonthOfService = b.MonthOfService
				  )
	    where a.ForecastMeg = "&Meg" and a.ForecastSvc = "&Svc" and a.MonthOfService in (select MonthOfService from tmp);
	  update PT_data as a
         set Federal = ( select newFederal
	                   from tmp as b
				       where a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc and a.MonthOfService = b.MonthOfService
				  )
	   where a.ForecastMeg = "&Meg" and a.ForecastSvc = "&Svc" and a.MonthOfService in (select MonthOfService from tmp);
	  
	   update PT_data as a
        set State = ( select newState
	                   from tmp as b
				       where a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc and a.MonthOfService = b.MonthOfService
				  )
	   where a.ForecastMeg = "&Meg" and a.ForecastSvc = "&Svc" and a.MonthOfService in (select MonthOfService from tmp);

	   update PT_data as a
        set local = ( select newLocal
	                   from tmp as b
				       where a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc and a.MonthOfService = b.MonthOfService
				  )
	   where a.ForecastMeg = "&Meg" and a.ForecastSvc = "&Svc" and a.MonthOfService in (select MonthOfService from tmp);

	   update Pt_data as a 
	     set ReleaseVerLetter = %upcase("&ReleaseVerLetter"),
	   	     Created = datetime(),
			 CreatedBy = "Xingguo"
			 %if &ForecastMeg= and &ForecastSvc = %then %do;
	           %put NOTE: I am here ;
	           %end;
	           %else %do;
	             where meg = "&ForecastMeg" and svc = "&ForecastSvc"
	           %end;
	    ;


 	quit;
	
   %leave:
   %end;
   %let rc = %sysfunc(close(&dsid));
   %put NOTE: the code is completed!!!;
%mend ETL;

/*Run for all cells */
%ETL(ForecastMeg=, ForecastSvc = , excludeStep = );

/* run for a given cell */
/*%ETL(ForecastMeg=1221, ForecastSvc = 630, excludeStep = );*/



/* Move the data to SQL server */

LIBNAME Forecast odbc noprompt="filedsn=&AfrsOdbcFileDsn;" user=%SYSGET(USERNAME) schema=zxg;
%macro Mov_2_Sql;
  
  proc sql;
  delete from forecast.my_D_Version
    where ThisCycle = "&cycle"  and ReleaseVerLetter = "&ReleaseVerLetter";
 
  insert into forecast.my_D_Version (ForecastMeg,ForecastSvc,MonthOfService,FiscalYear,BudgetUnit,ExpenditureSource,ForecastVersion,
                                     Eligible,Total,Federal,State,SNAF,Local,Tobacco,HSA,PerCap,ThisCycle,ReleaseVerLetter,Created,CreatedBy)
  select ForecastMeg,ForecastSvc,MonthOfService,put(FiscalYear,4.),BudgetUnit,ExpenditureSource,ForecastVersion,
                                     Eligible,Total,Federal,State,SNAF,Local,Tobacco,HSA,PerCap,ThisCycle,ReleaseVerLetter,Created,CreatedBy
  from PT_data;
  quit; 
%mend;

%Mov_2_Sql;
libname Forecast clear;



/* plot the data PT without step against PT with step */
%macro plotGraph(meg=1261, svc=610);
  %local meg svc;
proc sql;
  create table graph_&meg._&svc as 
  select a.ForecastMeg,a.ForecastSvc,input(a.MonthOfService||'01', yymmdd10.) as MonthOfService format=MONYY7.,
         a.PerCap as PerCapWithStep label = 'PerCapWithStep', b.StepPerCap as StepPerCap label ='StepPerCap',b.StepID,
		 c.PerCap as PerCapNoStep label = 'PerCapNoStep'
  from PT_data (where = (ForecastMeg = "&meg" and ForecastSvc = "&svc")) as a 
  inner join stepData (where = (Formeg = "&meg" and ForSvc = "&svc")) as b
    on a.ForecastMeg = b.Formeg and a.ForecastSvc = b.ForSvc
	  and a.MonthOfService = b.MonthOfService
  inner join PT_data_no_step as c
    on a.ForecastMeg = c.ForecastMeg  and a.ForecastSvc = c.ForecastSvc and a.MonthOfService = c.MonthOfService
  order by a.MonthOfService;
quit; 



ods graphics / width=1000px height=600px;
title "Step plot for the cell (&meg,&svc)";
proc sgplot data= graph_&meg._&svc;
   series x=MonthOfService y=StepPerCap/ group=StepID lineattrs=(thickness=2);
   series x=MonthOfService y=PerCapWithStep /lineattrs=(thickness=3 color = red );
   series x=MonthOfService y=PerCapNoStep/lineattrs=(thickness=3 color =purple);
   keylegend / location=outside position=E across=1 opaque ;
   xaxis grid;  yaxis grid;
   yaxis label = "PerCap" grid tickvalueformat = dollar10.3;
run;

%mend;

/*%plotGraph(meg=1211,svc=775);*/


%macro loop_graph;
  %local meg svc;
  proc sql ;
    create table graph_cell as 
    select distinct Meg,Svc 
	from sid_cell
/*	where Meg = "1221" and Svc  = "630"*/
	order by 1,2;
  quit; 
   
  %let dsid = %sysfunc(open(graph_cell));
   %syscall set(dsid);
   %do %while(%sysfunc(fetch(&dsid)) eq 0);
     %PUT NOTE:  I am in cell >>>>>>(&Meg, &svc)<<<<< ;
     %plotGraph(meg=&meg,svc=&svc);
  %end;
  %let rc = %sysfunc(close(&dsid));
%mend;


ODS RESULTS off; /* I AM HERE */
ods listing close;
ods graphics on;
options orientation=landscape;
options nodate nonumber;
ods pdf file =  "I:\MyAddingStepLog&cycle._&ReleaseVerLetter..pdf" style = sasWEB ;
%loop_graph;
ods pdf close;
ods listing;
ods Results;

data _null_;
  dur = datetime() - &_timer_start;
  put 30*'-' / ' TOTAL DURATION:' dur time13.2 / 30*'-';
run;


Proc PrintTo;
Run;


