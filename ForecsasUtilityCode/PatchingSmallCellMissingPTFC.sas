dm 'log' clear;

/* based on the data MissingSet from execution of the CheckingMissingPTFC.sas */

%let cycle=2517;

%macro FixMissing(meg = 1230, svc = 630, AverageFrom = 1, AverageTo=3);

data cell;
  set Mapredictedpercap;
  where forecastmeg = "&meg" and ForecastSvc = "&svc";
  run; 


proc sql noprint;
  select count(MaPredictedPercap) into: MaPtCount
  from cell
  where MaPredictedPercap is not missing;
 quit;

 %if &MaPtCount = 0 %then %do;
  %put NOTE: CELL (&meg,&svc) HAVE NO NONMISSING VALUES;
  %return;
  %end;

proc sql noprint;
  select MaPredictedPercap into: percap_fc1
  from cell
  where ServiceMonth = (
         select max(ServiceMonth) as FC_exist_ms
         from cell
         where MaPredictedPercap is not missing
  );
 
  quit;

  
  proc sql; 
  select MaPredictedPercap into: percap_fc2
  from cell
  where ServiceMonth = (
         select max(ServiceMonth) as FC_exist_ms
         from cell
         where MaPredictedPercap is not missing
		      and ServiceMonth ne ( select max(ServiceMonth) as FC_exist_ms
                                    from cell
                                    where MaPredictedPercap is not missing
                                   )
  );

  
  select min(ServiceMonth) as FC_missing_ms into: FC_missing_ms
  from cell
  where MaPredictedPercap is missing;
  
  %if %qsysfunc(inputn(&percap_fc1,20.12)) eq %qsysfunc(inputn(&percap_fc2,20.12)) %then %do;
   
   insert into UpdatedMissingCell (ForMeg,ForecastSvc,ServiceMonth,PrimaryTrendCellType,PerCap)
   select meg, svc, month,upcase(type),input("&percap_fc1", 20.12) as PerCap
   from MissingSet
   where meg = "&meg" and svc = "&svc" and month>=%sysfunc(inputn(&FC_missing_ms,6.));
  %end;
  %else %if %eval(&MaPtCount>=3) %then %do;
    create table t1 as
    select ServiceMonth,MaPredictedPercap 
    from cell
    where MaPredictedPercap is not null
    order by ServiceMonth desc;

	select ifn(avg(MaPredictedPercap)>0, avg(MaPredictedPercap),0) as percap format = 20.10 into: AvgPerCap
    from t1
    where monotonic() between &AverageFrom and &AverageTo;
    
    insert into UpdatedMissingCell (ForMeg,ForecastSvc,ServiceMonth,PrimaryTrendCellType,PerCap)
    select meg, svc, month,upcase(type),input("&AvgPerCap", 20.10) as PerCap
    from MissingSet
    where meg = "&meg" and svc = "&svc" and month>=%sysfunc(inputn(&FC_missing_ms,6.));
  
  %end;
  %else %do;
    %put cannot update;
	insert into NotUpdatedMissingCell(meg,svc)
	values("&meg","&svc");
  %end;

quit;
%mend;

%*%FixMissing;
%*%FixMissing(meg = 1861, svc = 777);

%macro FixingAllCells;
%local i meg svc;

proc sql noprint;
  create table NotUpdatedMissingCell (meg char(4),
                                      svc char(3)
						             );

  create table UpdatedMissingCell (ForMeg char(4),
                                   ForecastSvc char(3),
                                   ServiceMonth int,
                                   PrimaryTrendCellType char(1),
								   PerCap num format 20.10
								  );



  create table MissingMegSvc as 
  select distinct meg, svc
  from MissingSet;
/*  where meg = "1211" and svc = "221";*/
quit;

data _null_;
  set MissingMegSvc end = eof;
  total+1;
  call symputx("meg"||compress(_n_), meg);
  call symputx("svc"||compress(_n_),svc);
  if eof then call symput ('totct',total);
run; 

%let i =1;
%do %while(%eval(&i<=&totct));
   %let meg = &&meg&i;
   %let svc = &&svc&i;
/*   %put meg is >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>&meg;*/
/*   %put svc is >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>&svc;*/
/*   %return; */
   %FixMissing(meg = &meg, svc= &svc);
   %let i = %eval(&i+1);
%end;
%mend;





/* the cells updated  */


%macro Export2dest(type=L);

 %FixingAllCells;

 data updatedCells;
  set UpdatedMissingCell;
  where PerCap ne .;
 run; 

 proc sql;
   create table updatedCells_1 as
   select 'FID31' as ForElementIdentifier, *
   from updatedCells;
 quit; 


 proc print data =updatedCells_1;
 run; 
 %let dt=%sysfunc(today(),date9.)_%sysfunc(compress(%sysfunc(time(),time6),:));


 libname pch "Q:\ForecastOFM\Production\NwCycle&cycle._01\QC\overRideFmapPT\";

 data %if %upcase(&type) = L %then pch.LargePatch_&cycle._&dt; %else pch.SmallPatch_&cycle._&dt;;
   set updatedCells_1;
 run; 

 libname  pch clear;

%mend;

%Export2dest(type=S);

/* export the SAS file as CSV file  ------------------------------------
proc export data = updatedCells_1
  outfile="Q:\ForecastOFM\Production\NwCycle1912_01\QC\overRideFmapPT\update_PT_&cycle._override&dt..csv"
           dbms=csv
           replace;
quit;

*/


/*the cells not updated */

proc print data =  NotUpdatedMissingCell;
run; 
