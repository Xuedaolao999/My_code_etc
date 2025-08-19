/**************************************************************************
Author: ZXG
Purpose: To check if the current small cell PT is way different then the 
         prior one; this can also be use to check the large cell
***************************************************************************/

dm 'log' clear;


/* Define the forecast time window*/
%let ForecastStartMonth = 201703;
%let ForecastEndMOnth = 201906;

/* To single out those cells that have big different in PT*/


%macro Get_date(type = s);
libname current "Q:\ForecastOFM\Production\NwCycle1724_01\Data\SourceIn";
libname prior "Q:\ForecastOFM\Production\NwCycle1717_01\Data\SourceIn";

data current_%upcase(&type) ; /* current_small*/
  set current.mapredictedpercap_13sep2017_1101  ;
  where upcase(PrimaryTrendCellType) = %upcase("&type") and ServiceMonth >=&ForecastStartMonth;
  Date = mdy(substr(put(ServiceMonth,6.),5,2),1,substr(put(ServiceMonth,6.),1,4));
run; 



data prior_%upcase(&type); /* prior_small; */
  set prior.mapredictedpercap_09feb2017_1122;
  where upcase(PrimaryTrendCellType) = %upcase("&type") and ServiceMonth >=&ForecastStartMonth;
  Date = mdy(substr(put(ServiceMonth,6.),5,2),1,substr(put(ServiceMonth,6.),1,4));
run; 

libname current clear;
libname prior clear;

proc sql;
  create table current_prior as 
  select a.ForecastMeg, a.ForecastSvc, a.ServiceMonth, a.date, a.MaPredictedPercap as current_MaPredictedPercap, b.MaPredictedPercap as prior_MaPredictedPercap 
  from current_%upcase(&type) as a 
  inner join prior_%upcase(&type) as b
    on a.ForecastMeg = b.ForecastMeg 
       and a.ForecastSvc = b.ForecastSvc
	   and a.ServiceMonth = b.ServiceMonth;
quit;

%mend;

%macro process_data (type = s);

%if %upcase(&type) = S %then %do;
  %let SumThreshold = 1.5;
  %let AvgThreshold = 1.5;
%end;
%else %do;
  %let SumThreshold = 0.5;
  %let AvgThreshold = 0.5;
%end;
proc sql;

  create table current_prior_agg as 
  select ForecastMeg, ForecastSvc,
         sum(current_MaPredictedPercap) as sum_current_MaPredictedPercap,  
         sum(prior_MaPredictedPercap ) as sum_prior_MaPredictedPercap, 
		 avg(current_MaPredictedPercap) as avg_current_MaPredictedPercap,
		 avg(prior_MaPredictedPercap) as avg_prior_MaPredictedPercap,
		 (calculated sum_current_MaPredictedPercap - calculated sum_prior_MaPredictedPercap)/calculated sum_prior_MaPredictedPercap as PctDiffSumPerCap format = Percent10.4,
		 (calculated avg_current_MaPredictedPercap - calculated avg_prior_MaPredictedPercap) / calculated avg_prior_MaPredictedPercap as PctDiffAvgPercap format =Percent10.4
  from current_prior
  group by ForecastMeg, ForecastSvc
  having PctDiffSumPerCap>=&SumThreshold or PctDiffAvgPercap>=&AvgThreshold;


  create table cell_plot as 
  select a.*, b.PctDiffSumPerCap, b.PctDiffAvgPercap
  from current_prior as a 
  inner join current_prior_agg as b
    on a.ForecastMeg = b.ForecastMeg and a.ForecastSvc = b.ForecastSvc;
quit; 

%mend;


%macro PLOT_DATA (Meg = 1720, svc = 290 );
   proc sql noprint;
     create table Plot_data as 
     select *
     from cell_plot
     where ForecastMeg = "&meg" and  ForecastSvc  = "&svc";

	 select distinct PctDiffSumPerCap, PctDiffAvgPercap  into: SumDiff, :AvgDiff
	 from Plot_data;
   
    quit;

  

   ods pdf style=scell; 

   proc sgplot data=Plot_data ASPECT = 0.5 CYCLEATTRS DESCRIPTION="Forecasting plot"  NOOPAQUE;
       Title1  j=c h=1.5 c=blue  "Cell(&meg,&svc)" ;
       Title2  j=c h=1.00 c=blue  " PerCap Aggregate Percent Difference is &SumDiff" ;
       Title3  j=c h=1.00 c=blue   "PerCap Average Percent Difference is &AvgDiff" ;
      
       series x=Date y=current_MaPredictedPercap / lineattrs= (pattern=1 thickness =3 color = r ) 
                            LEGENDLABEL = "Current PerCap" name = "fc" MARKERS MARKERATTRS = (symbol=TriangleRightFilled color=purple  size = 5px);

       series x=Date y=prior_MaPredictedPercap /  lineattrs=(pattern=1 thickness=3 color = blue ) LEGENDLABEL = "Prior PerCap" name = "stfc"
                                   Markers MARKERATTRS = (symbol=Triangle color=purple size = 5px) ;
 
       xaxis label = "Date"  minor MINORCOUNT = 2 type = time TICKVALUEFORMAT=MONYY7. fitpolicy = ROTATETHIN GRID ;

       yaxis label = "PerCap Expenditure" grid tickvalueformat = dollar10.2;
   
   quit;
%mend;





%MACRO Plot_The_cells(type = s);
  %Get_date (type = &type);
  %process_data(type = &type);
  proc sql;
    select distinct catt(ForecastMeg,'|', ForecastSvc) into :MegSvc separated BY ','
    from cell_plot;
  quit; 
 
  ODS NORESULTS;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
  ods listing close;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
  goptions reset=all dev=sasprtc ;  

  proc template;
   define style styles.scell; 
   parent = styles.default;
   style GraphValueText from GraphValueText / font=('Arial', 8pt, Normal);
   style GraphLabelText from GraphLabelText / font=('Arial', 10pt, Bold);
   style GraphBorderLines from GraphBorderLines /LineThickness=0 linestyle = 4;
   style GraphWalls from GraphWalls / color= LIGGR  ;
   style GraphBackground / transparency=0 ;
   style Container /backgroundcolor = white;
   end;
  run;

  ods pdf file =  "Q:\ForecastOFM\Production\NwCycle1724_02\QC\Cell_PT_1724_Checking_%upcase(&type).pdf" style = sasWEB ;
  %local i;
  %let i = 1; 
  %let MS = %scan(%bquote(&MegSvc), &i, %str(,));
  %do %while (%length(&MS)>0) ;
      %let meg = %scan(&MS,1,%str(|));
	  %let svc = %scan(&MS,2,%str(|));
	  %PLOT_DATA(Meg = &meg, svc =&svc );
	  %let i = %eval(&i+1);
	  %let MS = %scan(%bquote(&MegSvc), &i, %str(,));
  %end;
  ods pdf close; 
  ODS RESULTS;
  ods listing;
  %mend;


%Plot_The_cells(type = s); 












   


