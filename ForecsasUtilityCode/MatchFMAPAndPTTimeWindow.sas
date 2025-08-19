/**********************************************************************************
* Author: ZXG
* Date: 1/26/2018
* Purpose: to align the time window between PT predicted and FMAP predict so that the 
*          PT and FMAP have the same starting date and ending date
************************************************************************************/
/*option mlogic mprint;*/
dm 'log' clear;
%let cycle = 2517;

%let PT_File = Mapredictedpercap_31jan2025_1015 ;
%let FMAP_File = mapredallocation_2517_31jan2025;

/*Create the copy of the MaPredicted in the work library*/
libname Checking "Q:\ForecastOFM\Production\NwCycle&cycle._01\Data\SourceIn";

Data PT;
  set checking.&PT_File;
 * where ForecastMeg = "1252" and ForecastSvc = "450";
run; 

Data Fmap;
  set Checking.&FMAP_File;
  *where ForecastMeg = "1252" and ForecastSvc = "450";
run; 



/*cell (671,1221) will be starting from Jan 01, 2015 */
proc sql noprint;
  select distinct ForecastMeg ||"_"|| ForecastSvc into: PT_cell  separated  by ","
  from PT;
QUIT;
 

proc sql;
  create table MisMatchedCell (ForMeg char(4),
                                   ForSvc char(3),
                                   PT_Month int,
								   FMAP_Month int
                                   );
quit;


 
%macro AlignTheTimeWindow (meg = 1212, svc = 450);
  
 proc sql noprint;
  select min(ServiceMonth) into:min_mos1
  from PT
  where ForecastMeg = "&meg" and ForecastSvc = "&svc" ;

  select min(ServiceMonth) into:min_mos2
  from FMAP
  where ForecastMeg = "&meg" and ForecastSvc = "&svc" ; 

  %if &min_mos1 ^= &min_mos2 %then %do;
    insert into MisMatchedCell (ForMeg,ForSvc,PT_Month,FMAP_Month)
	values("&meg","&svc",&min_mos1,&min_mos2);
  %end;
 quit; 
 
 

 %if  (&min_mos1>= &min_mos2) %then %do;
   %put NOTE: PT Starts Later;
   proc sql noprint;
     delete 
	 from FMAP
	 where ServiceMonth<&min_mos1
           and ForecastMeg = "&meg" and ForecastSvc = "&svc" ; 
 %end;
 %else %do;
   %put NOTE: PT Starts Earlier!;
   proc sql noprint;
     delete 
	 from PT
	 where ServiceMonth<&min_mos2
     and ForecastMeg = "&meg" and ForecastSvc = "&svc";
   quit;

 %end;
%mend;

%*%AlignTheTimeWindow;

%macro LoopOverCell;
  %local i meg cell j svc;
  %let i =1;
  %let cell = %scan(%bquote(&PT_cell),&i,%str(,));
  %do %while(%length(&cell)>0);
    %let meg=%scan(&cell,1,%str(_));
	%let svc=%scan(&cell,2,%str(_));
    %put NOTE: meg is &meg;
	%put NOTE: svc is &svc;
	%if &meg = 1221x and &svc = 671 %then %do;
	   proc sql noprint;
	     delete 
		 from PT
		 WHERE ServiceMonth<201501
         and ForecastMeg = "1221" and ForecastSvc = "671";
	    
		 delete 
		 from FMAP
         where ServiceMonth<201501
           and ForecastMeg = "1221" and ForecastSvc = "671";
	  quit;
	%end;
	%else %do;
	  %AlignTheTimeWindow (meg = &meg, svc = &svc);
	%end;
    %let i = &i+1;
    %let cell =%scan(%bquote(&PT_cell),&i,%str(,));
  %end;
 %mend;
%LoopOverCell;

%let dt=%sysfunc(today(),date9.)_%sysfunc(compress(%sysfunc(time(),time6),:));
/*%put &dt;*/


data Checking.new_&cycle._PT_&dt;
 set PT;
run;

data Checking.new_&cycle._FMAP_&dt;
 set FMAP;
run;

libname Checking clear;


/* Checking the cells that have mismatched time window of FMAP and PT */
data missFmap (keep = ForMeg ForSvc ) missPT (keep = ForMeg ForSvc ); 
  set MisMatchedCell  ;
  if FMAP_Month = . then output missFmap;
  if PT_Month = . then output missPT;
run;  
  

title "Cells without FMAP";
proc print data = missFmap;
run; 

title "Cells without PT";
proc print data = missPT;
run; 
