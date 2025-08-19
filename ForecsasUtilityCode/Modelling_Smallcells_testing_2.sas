/*
 This ad hoc can be used to deal with the situation when there is not estimation is created,
 and other issues, this is good one
*/

%MACRO Modelling_Smallcells;


%SetDebugSasOptions(LEVEL7); %LET Debug = LEVEL7; 

options symbolgen mprint;
options noxwait noxsync;

/*ZXG: modified on February 7, 2023 */
%if %sysfunc(exist(PmTrend.cell_25_missing)) %then %do;
	  %put NOTE: the table PmTrend.cell_25_missing exists!;
	%end;
	%else %do;
      proc sql;
       create table PmTrend.cell_25_missing 
         ( MEG char(4) not null,
           SVC char(3) not null,
           nbr_no_missing num,
           time_frame num ,
           from_mos num  format=MONYY7., 
           to_mos num format=MONYY7. 
          );
     quit; 

   %end;


/*(SC) Set up timestamp under title in the graphic. */
   %let timenow=%sysfunc(time(), time.);			
   %let datenow=%sysfunc(date(), date9.);


GOPTIONS cback=lightgreen;


proc sql;
  drop table PmTrend.SmallCells;
quit;
 

%ImportExcelFile(ExternalFile=&pDExternel.ExParameters.xls,
			OutputFullDsn=PmTrend.SmallCells,Sheet=CurrentSmallCells);

%LET ProcUCMlExists = %SYSPROD(ETS);


%LET dsidm=%SYSFUNC(OPEN(pmtrend.smallcells(WHERE=(upcase(selected)="X"))));


	%LET CountObs=%QSYSFUNC(ATTRN(&dsidm, nlobs));
	%PUT NOTE: (SD) Total Observations: &CountObs;

	%DO %WHILE(%SYSFUNC(FETCH(&dsidm)) EQ 0);
			%LET category=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, category))));
			%LET Service=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, Service))));
			%LET PctExpenditure=%SYSFUNC(GETVARN(&dsidm, %SYSFUNC(VARNUM(&dsidm, PctExpenditure))));
			%LET Exo=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, Exo)))); 
			%LET List=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, list))));
			%LET Test=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, Test))));
			%LET Keep=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, Keep))));
			%LET Selected=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, Selected))));
			%LET SixAve=%SYSFUNC(GETVARN(&dsidm, %SYSFUNC(VARNUM(&dsidm, SixAve))));
			%LET ScCutOff=%SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, CutOff))));
			%LET Completed = %SYSFUNC(GETVARC(&dsidm, %SYSFUNC(VARNUM(&dsidm, Completed))));
			
			%IF &Completed = 1 %then %goto done;

            proc sql; 
             drop table PmTrend.UcmSts_&category._&service;
		     drop table PmTrend.UcmInputData_&category._&service;
			 drop table UcmSts_&category._&service;
		    quit;
             
			%LOCAL lastDateofacutalData1;
		    %LET lastDateofacutalData1=%SYSFUNC(INTNX(MONTH, &lastDateofacutalData, %EVAL(-1*&ScCutOff))); 
			/* zxg: adjjust the lastDateofacutalData1 can affect the average ussed in the prediton Aug 25, 2022  */

            Data pmtrend.UcmInputData_&category._&service(WHERE=(date LE &LastDateOfAcutalData1));
			  Set pmTrend.ModelInput(WHERE=(category="&category" AND Service="&service"));
			  RENAME MOS=Date;
			  KEEP mos PerCap Fratio bratio;
			  CALL SYMPUT("Fratio", Fratio);
			  CALL SYMPUT("bratio", bratio);
		    Run;
			
			
		
        %local FirstDateofProjectedData1;
		%let FirstDateofProjectedData1 = %sysfunc(intnx(month, &lastDateofacutalData1, 1));
		
		%LET n=%SYSFUNC(INTCK(MONTH, &FirstDateofProjectedData1, &LastDateofProjectedData));
		%LET lead=&n;
		%PUT NOTE: (SD) N=&n;


		Data fcstdata(drop=i);
		  DO i= 1 to %EVAL(&n+1);
			DATE=intnx('MONTH', &FirstDateofProjectedData1, i-1);
			percap=.;
			Fratio=&Fratio;
			Bratio=&Bratio;
			OUTPUT;
		  END;
		  FORMAT DATE MONYY7.;
		Run;

		Proc Append data=fcstData BASE=pmtrend.UcmInputData_&category._&service;
		Run;

			
       %NewPalette(&category, &service, UCM, Smallcells);
       


/*(SC)Add Meg-Category and Service names to the file for later use in the GPlot code*/
/*These two files identify each MEG and Service number*/
/*This same script is utilized in the FMAP process to define MEG and Services*/

%if %sysfunc(exist(z5)) %then %do;
    %put NOTE: FILE z5 exists;
	 proc datasets lib=PmTrend;
	   delete z5;
	 quit;
  %end;

proc sql noprint;
  create table z5 as 
  select distinct a.category as ForMeg,a.service as ForSvc, 
  case (a.service)
    when '101' then  'Clinic - School Medical'
    when '103' then  'Licensed Health Care Professionals'
	when  '211' then  'Diagnosis Related Grouper/Per Diem'
	when  '221' then  'RCC/Critical Access Hospital/Crossover'
	when  '223' then  'Inpatient-Certified Public Expenditure'
	when  '333' then  'Federally Qualified Health Center Encounter Differential'
	when  '343' then  'Clinic-Rural Health Clinic Services'
	when  '336' then  'Healthy Options-Federally Qualified Health Centers/Rural Health Clinic MC Enhancements'
	when  '413' then  'Drug Expenditures-Mental Health, Regional Support Network'
	when  '740' then  'Durable Medical Equipment'
    else strip(c.ForSvcName) 
   end as ForSvcName,
   case strip(a.category)
	when  '1212' then  'CN TANF - FFS'
	when  '1221' then  'ACA Expansion - MC Enrolled'
	when  '1222' then  'ACA Expansion - FFS'
	when  '1251' then  'CN Blind/Disabled - MC Enrolled'
	when  '1252' then  'CN Blind/Disabled - FFS'
	when  '1280' then  'Other Disabled Breast/Cervical Cancer Treatment'
	when  '1290' then  'Medicaid Buy-In Healthcare for Workers w/ Disabilities'
	when  '1296' then  'Medicare Savings Program-Qualified Medicare Beneficiary SLMB Quality Improvement'
	when  '1253' then  'T19 Categorically Needy Disabled Presumptive SSI'
	when  '1970' then  'Cover All Kids'
	when  '2230' then  'Qualified Medicare Beneficiary Only-Partial Duel'
    else strip(b.ForMegName) 
   end as ForMegName
  from pmTrend.ModelInput as a 
  left join MainDM.Dim_for_MEG  as b
    on a.category = b.ForMeg
  left join MainDM.Dim_for_Svc as c
    on a.service = c.ForSvc
  where upcase(a.category) =%upcase("&Category")
        and upcase(a.service) = %upcase("&Service");
  
  select distinct ForMegName,ForSvcName into :CategoryName,:ServiceName
  from z5;

quit;



*** BEGIN: To create the Frontice Sheet *******************************************;
/*(SC)Make titles and footnotes consistent with the large cell graphics package*/
		Title1 	h=1.5 	c=blue  "**** Primary Trend of Small Cell****" ;
		Title2 	h=1.0 	c=blue "&Forecast" ;
		Title3 	h=1.0 	c=blue "Service  &service = &ServiceName" ;
		Title4 	h=1.0 	c=blue "Category &category = &CategoryName" ;
		Title5	h=1.0 	c=red "(%SYSFUNC(round(&pctExpenditure*100, 0.0001)) % of Total Expenditure)";	 
	  	Title6 	h=1.0 	c=blue "OFM Forecasting and Research";
		Title7 " ";
	  	Title8  h = 1.0 c=blue " Proc UCM: " c=brown " AdjPercap = &list ";
	  	Title9 " ";

      Footnote j=r h = 0.7  "OFM Forecasting and Research: %Date %Time";


/*(SC)proclabel just sets up the TOC (table of contents) as the head label*/
      



      %PUT NOTE: (KC) Proc UCM Called for &category * &service;
/**********************added by Shidong  11/16/2006*****************************/
   DATA Track.Rmse_smallcells_&pDataCycle._&pDataVersion;
   		SET Track.Rmse_smallcells_&pDataCycle._&pDataVersion;
		IF category = &category AND service = &service THEN DELETE;
	RUN;
   

   


	/******************* Special treatment to CPE part 1 **************************************/
	%CPESpecialSmallCell(&category, &Service, A);
      %IF &ProcUcmlExists EQ 1 %THEN %DO;
			ods select ParameterEstimates  ResidSummary;
 			ODS OUTPUT 'Goodness of Fit' = RMS_&category._&service;
            ODS RESULTS off; /* I AM HERE */
            ods listing close;
            ods graphics on;
            options orientation=landscape;
            options nodate nonumber;
            ods pdf file =  "&pDPTrendGraph.S_&fCycle._&service._&category._Afrs&pDataCycle..pdf" style = sasWEB ;
            /*%put NOTE: file is >>>>>>>>>>>>>>>>>>>>>>>>"&pDPTrendGraph.S_&fCycle._&service._&category._Afrs&pDataCycle..pdf";*/
            /*%RETURN;*/

            
/* zxg: modified on 3/13/2023                                          */
          %ucm_proc(cat=&category,svc=&service,ld=&lead);
          
          

         /* zxg: modified on February 7, 2023	 -------------------------------------------  */
         proc sql noprint;
           select nobs into :n_obs 
           from dictionary.tables
           where libname = 'WORK'
             and memname = %UPCASE("UcmSts_&category._&service");
         quit;

		 %if &n_obs = 0 %then %do;
		    proc sql noprint;
		       select min(date), max(date) ,count(*) into: d_fro, :d_to, :t_frame separated by ' '
               from PmTrend.UcmInputData_&category._&service;
			

               select count(*) into: _no_missing
               from  PmTrend.UcmInputData_&category._&service
               where perCap ^=. ;
               
			   /* zxg: replacing the missing values with zeor in the input data */
               create table work.Ucminputdata_&category._&service as 
			   select *
			   from pmtrend.Ucminputdata_&category._&service;
              
			   update work.Ucminputdata_&category._&service
			     set percap=0,
	                  adjpercap=0
               where percap =. and adjpercap= . and date<=&lastDateofacutalData1;

			   select count(*) into:_nrow
			   from PmTrend.cell_25_missing
			   where meg = "&category" and svc = "&service";

			   %if &_nrow = 0 %then %do;

                insert into PmTrend.cell_25_missing (meg, svc,nbr_no_missing,time_frame, from_mos,to_mos)
			    values("&category", "&service",&_no_missing,&t_frame,&d_fro,&d_to);
			   %end;

           quit;
		    ods select ParameterEstimates  ResidSummary;
 			ODS OUTPUT 'Goodness of Fit' = RMS_&category._&service;
            %ucm_proc_missing(lib=work, cat=&category,svc=&service,ld=&lead);

		  %end;
      %END;  
	footnote;
/* Create additional Model Tables and Reports and output ODS PDF and Excel*/
	Data _null_;  
         EDInd = Intck('month','01jan1960'd,&lastDateofacutalData1);
         Back12Ind = EDInd - 11;                               
         Back12date = Intnx('month','01jan1960'd,Back12Ind);   
         call symput('Back12Date',Back12Date);            
         Lead = Intck('month',&lastDateofacutalData1,&LastDateOfProjectedData)+1;   
         call symput('Lead',Lead); 
	Run; 
      

/* (SC)This sql code creates the minimum and maximum values
     of the Adjusted percap during the last twelve months of data
     for use in the following data step, which makes use
     of these values to stop runaway forecaUCM.*/
  Proc SQL noprint;
     create table work.limits_&category._&service as
     select min(AdjPerCap) as MinPerCap,
            max(AdjPerCap) as MaxPerCap
     from work.UcmSts_&category._&service
     where date >= &Back12Date and date <= &lastDateofacutalData1;

     create table PmTrend.UcmSts_&category._&service
     as select * from
     work.UcmSts_&category._&service as R
     left join
     limits_&category._&service
     on R.date ne .;
	Quit;

          %SumColumInATable(PmTrend.UcmSts_&category._&service(where=(date GE &FirstDateOfProjectedData1 )),AdjPerCap);
          %LET SumPredictedValeus1 = &ReturnValue;
          %PUT SumPredictedValeus1: &SumPredictedValeus1;

  %* This data step puts a limit on runaway forecasts. *;

  %LOCAL LimitFlag;
  %LET LimitFlag = No; * Initialize;
  Data _null_;
     set PmTrend.UcmSts_&category._&service;
     LimitHigh = MaxPerCap * 1.5;
     LimitLow = MinPerCap * .5;
     if date > &lastDateofacutalData1 and Forecast > LimitHigh then
        call symput('LimitFlag','Yes');
     if date > &lastDateofacutalData1 and Forecast < LimitLow then
        call symput('LimitFlag','Yes');
  Run;
  
  %IF &LimitFlag = Yes OR &SixAve = 1 %THEN %DO;
   

/*(SC) Calculate the Actual PerCap for the most recent 6 months (ave6)*/
/*zxg ------------------------- adjust the time  window for the average */
    
    proc sql noprint;
       create table work.ave6_&category._&service as
       select mean(AdjPerCap) as ave6
       from PmTrend.UcmInputData_&category._&service
       where date >= INTNX('month',&LastDateOfAcutalData1,-6) and date <= &LastDateOfAcutalData1
/*             and date^='01Feb2021'd*/
			 ;
	         /* modified by ZXG on 9/21/2016*/
      
       create table PmTrend.UcmSts_&category._&service 
       as select r.*, a.ave6
       from PmTrend.UcmSts_&category._&service as r
       left join
       ave6_&category._&service as a
       on r.date ne .
       order by date;
       quit;
  
    
	Data PmTrend.UcmSts_&category._&service;   
       Set PmTrend.UcmSts_&category._&service;
       if date > &LastDateOfAcutalData1 then  Forecast = ave6;
	Run;



      %LET MaaProcUcmRs = 0;
      %LET ReturnMessage = WARNING: Predicted values have been limited by the 0.5 to 1.5 process.;
      %PUT WARNING: (KC) &ReturnMessage;

  %END;

   
          %SumColumInATable(PmTrend.UcmSts_&category._&service(where=(date GE &FirstDateofProjectedData1 )),AdjPerCap);
          %LET SumPredictedValeus2 = &ReturnValue;
          %PUT SumPredictedValeus2: &SumPredictedValeus2;
   
/* zxg: this is important to change the value */
	Data PmTrend.UcmSts_&category._&service;  
        Set PmTrend.UcmSts_&category._&service;
    	if AdjPerCap ne .  then Forecast = .;
   	    *if AdjPerCap = . then AdjPerCap = Forecast; /* modified by zxg on 9/19/2016 */
	   	Zero=0;
	 	
	Run;

	   /********** Special Treatment to CPE part 2 **************************/
		%CPESpecialSmallCell(&category, &Service, B);

    Data PmTrend.UcmSts_&category._&service;
       Set PmTrend.UcmSts_&category._&service;
       d12 = AdjPerCap - lag12(AdjPerCap);
       if lag12(AdjPerCap) GT 0 then pd12 = d12/lag12(AdjPerCap);
    Run;

	   /*******************Added by Shidong*****************************************/
	   %IF &LimitFlag = No %THEN %DO;

	/*****************************Shidong Add 07/10/2006*************************************/
	Data RMS_&category._&service._c (KEEP= category service rmse);
		Set RMS_&category._&service;
		if FitStatistic = 'Root Mean Squared Error';
		category=&category;
		service=&service;
		rmse=value;
	RUN;

	PROC APPEND base=Track.rmse_SmallCells_&pDataCycle._&pDataVersion DATA=RMS_&category._&service._c;
	RUN;
	%END;

	
  	PROC SQL NOPRINT;
		CREATE TABLE _Stemp AS
		SELECT a.*, b.PriorPerCap,b.STPriorPerCap
		FROM PmTrend.UcmSts_&category._&service AS a
		LEFT JOIN Etlmd.PriorPT(WHERE=(category="&category" AND Service="&service")) AS b
		ON a.Date EQ b.Date
		ORDER BY a.Date;
	QUIT;
    
	
	Data PmTrend.UcmSts_&category._&service; 
      Set _Stemp;
	  if Forecast EQ . THEN predict=STPriorPerCap; 
		else predict=Forecast;
	  format adjPercap PriorPerCap Forecast STPriorPerCap dollar19.4;
	  label adjPerCap='Actual PerCap';
	  label Forecast='Predicted PerCap';
	  label STPriorPerCap='Prior PerCap w/ Steps';
	Run;
  


  /* ZXG modified on 11/28/2016	*/
ods graphics on / width = 8.5 in height=6.5 in ;

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

ods pdf style=scell; 

%put Note: the file is PmTrend.UcmSts_&category._&service;

proc sgplot data=PmTrend.UcmSts_&category._&service ASPECT = 0.5 CYCLEATTRS DESCRIPTION="Forecasting plot"  NOOPAQUE;
  Title1  j=c h=1.0 c=blue  "&Forecast" ;
  Title2  j=c h=1.00 c=blue  " Service  &service = &serviceName" ;
  Title3  j=c h=1.00 c=blue   "	Category &category = &categoryName" ;
  Title4  j=c h=1.00 c=red    " (%SYSFUNC(round(&pctExpenditure*100, 0.0001)) % of Total Expenditure)";	 
  series x=date y=Forecast / lineattrs= (pattern=1 thickness =3 color = r ) 
                            LEGENDLABEL = "Predicted PerCap" name = "fc" MARKERS MARKERATTRS = (symbol=TriangleRightFilled color=purple  size = 5px);

  series x=date y=STPriorPerCap /  lineattrs=(pattern=1 thickness=3 color = blue ) LEGENDLABEL = "Prior PerCap w/Steps" name = "stfc"
                                   Markers MARKERATTRS = (symbol=Triangle color=purple size = 5px) ;
  series x=date y=PriorPerCap / LEGENDLABEL = "PriorPerCap"  LINEATTRS = (pattern=1 color=  yellow  thickness = 3)
                               MARKERS MARKERATTRS = (symbol=diamond color=red size = 5px) ;
  series x=date y=adjPercap/LEGENDLABEL = "Actual PerCap" LINEATTRS = (pattern = 1 color = brown thickness = 3) markers markerattrs = (sybmol = Homedown color = purple size = 5px);
  xaxis label = "Date"  minor MINORCOUNT = 2 type = time TICKVALUEFORMAT=MONYY7. fitpolicy = ROTATETHIN GRID ;

  yaxis label = "PerCap Expenditure" grid tickvalueformat = dollar10.2;
run;
quit;


   

    /*ReInterating the titles for the final data list*/
		Title1 j=c	h=1.50 c=blue "Data Used in the Preceding Graphs";
		Title2 j=c  h=1.00 c=blue &Forecast;
		Title3 j=c 	h=1.00 c=blue "Service  &service = &serviceName" ;
		Title4 j=c  h=1.00 c=blue "Category &category = &categoryName" ;
		Title5 j=c 	h=1.00 c=red "(%SYSFUNC(round(&pctExpenditure*100, 0.0001)) % of Total Expenditure)";
Footnote j=r h = 0.7  "OFM Forecasting and Research: %Date %Time";
ods pdf style = sasWEB;
	Proc Print data=Pmtrend.UcmSts_&category._&service label
	    style (obsheader)={background = yellow color = blue}
        style (data) = {background =white  }
        style (header) = {background = yellow color = blue};
		var Date adjPercap Forecast PriorPerCap STPriorPerCap Residual Std ;
		format pd12 percent10.2;
		format adjPercap PriorPerCap  STPriorPerCap dollar19.4;
		label adjPerCap='Actual PerCap';
		label Forecast='Predicted PerCap';
		label STPriorPerCap = "Prior PerCap w/Steps";
	Run;
   
    title; footnote;
 
	
 ods pdf close;

   
   ods listing;
   ods Results;
   



   /*(SC)xsync allows the ods xml file to be built before proceding to conversion to xlsx below*/
   options noxwait xsync;

   /*(SC)Convert the xml file just created to a smaller xlsx file, then delete the large xml file*/
/*   Data _null_;*/
/*     file "&xml\temp.vbs";*/
/*     put 'Set objExcel = CreateObject("Excel.Application")';*/
/*     put 'objExcel.Visible = FALSE';*/
/*     put 'objExcel.DisplayAlerts = FALSE';*/
/*     put %unquote(%nrbquote('Set objWorkbook = objExcel.Workbooks.Open("&xml.\S_&fCycle._&service._&category._Afrs&pDataCycle..xml")'));*/
/*     put %unquote(%nrbquote('objExcel.ActiveWorkbook.SaveAs"&xml.\S_&fCycle._&service._&category._Afrs&pDataCycle..xlsx",51'));*/
/*     put 'objExcel.ActiveWorkbook.Close';*/
/*     put 'objExcel.Quit';*/
/*   Run; Quit;*/
/*   x " ""&xml.temp.vbs"" ";   /*Execute VB Script */*/
/*   X del "&xml\S_&fCycle._&service._&category._Afrs&pDataCycle..xml"; 	*/
/*   X del "&xml\temp.vbs"; 	*/


   /*(SC)Copy the xlsx file just created into the PrimaryTrend/Small Cells folder of the U:drive*/
   /*&fCycle resolves to the forecast month-year, Feb2016 at this time*/

/*   x copy 	"&xml.\S_&fCycle._&service._&category._Afrs&pDataCycle..xlsx" */    */took out as it is not necessary - nh*/
/*				"&Udrive.\S_&fCycle._&service._&category._Afrs&pDataCycle._%unquote(%sysfunc(datetime(),mydtfmt.)).xlsx" /Y;*/



   

   * Create Dataset of Results to be appended to all Results;
   %DropTable(work.R_&category._&service._Ucm);
   %LET ReturnValue = ;

   Data work.R_&category._&service._Ucm;
	  Set PmTrend.UcmSts_&category._&service(keep=Date AdjPerCap rename=(AdjPerCap=Percap));
      if &category GT 1200 then do;
       total = Percap;
       Percap = 0;
       Eligible = 0;
      end;
    **else Eligible = Total / Percap;
    ExpenditureCategoryMcFfs = put(&category,z4.);
    BoAfrsService = put(&service,z2.);
    rename date = MonthOfService total=Amount;
    DataCycle = "&pDataCycle";
    DataVersion = "&pDataVersion";
   Run;

    %IF %SYSFUNC(EXIST(work.R_&category._&service._Ucm)) %THEN %LET ReturnValue = work.R_&category._&service._Ucm;
    %ELSE %LET ReturnValue = ;

  	
   proc datasets library=work;
	delete z5;
   Quit;  

  
     
  %done: %END;
  %LET RC=%SYSFUNC(CLOSE(&dsidm));
   
    

%MEND;


/*

%MethodRegistration(&pPrimaryTrend, Modelling_Smallcells);  

*/





/*(SC) Use these assignments to run code below outside the macro environment*/
/*
%let service=671;
%let category=1862;
%let fCycle=Feb2016;
%let pDataCycle=1705;
%let ResultsTableName=R_1221_630_newmodel_1524_1;    */

