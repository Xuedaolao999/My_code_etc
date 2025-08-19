/*
 This ad hoc can be used to deal with the situation when there is not estimation is created,
 and other issues
*/

%MACRO Modelling_Smallcells;


%SetDebugSasOptions(LEVEL7); %LET Debug = LEVEL7; 

options symbolgen mprint;
options noxwait noxsync;




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
	 proc datasets lib=work;
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
   
/*ZXG: Modified on 8/10/2022 to deal too many missing value in the input */
    %if &category = 1500 and &service=772 %then %do;
	   %put i am in here++++++++++++++++++++ &LastDateOfAcutalData1;
       data PmTrend.UcmInputData_&category._&service;
      set PmTrend.UcmInputData_&category._&service;
      if AdjPerCap = . and date <= &LastDateOfAcutalData1. then AdjPerCap = 0;
   run;
      
	%end;
	%else %do;
	DATA PmTrend.Ucminputdata_&category._&service(WHERE=(DATE GE &ScCutOff));
		SET PmTrend.Ucminputdata_&category._&service;
		IF Date LE &lastDateofacutalData1 THEN DO;
			/*IF perCap=. THEN percap=0;*/
			IF adjPerCap=. THEN adjPerCap=0;
			adjPerCap=PerCap;   /* This is because ineffective of fratios */
		END;
		*IF DATE LT "01JUL2005"d THEN D_jul05=1;
		*ELSE D_jul05=0;
	RUN;
   %end;
   


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

/*zxg: to adjust the lead value due to too many missing value leading to no estimation  */
%if &category = 1470x and &service = 751 %then %do;
  %let lead = %eval(&lead+22);
  %put lead now is ++++++++++++++++++++&lead;
 %end;

 

/*ZXG: can modify the model options to produce the model output for the cell that otherwise has not model oupput */
          proc ucm data = PmTrend.UcmInputData_&category._&service; *noprint; /***Shidong deletes 07/11/2006***/
           id date interval = month;
           model AdjPerCap = &list;
           irregular;
           level;
           slope;
           season length = 12 type = trig;
           estimate;
           forecast lead = %EVAL(&lead+1) print=decomp 
                    outfor = work.UcmSts_&category._&service (keep =  Date adjPercap FORECAST  S_NoirReg RESIDUAL STD LCL  UCL  );
          run;

      %END;
      %IF &ProcUcmlExists EQ 0 %THEN %DO;
       data _null_;
         file "&oGenerateDocsPath\MaaProcUcm.sas";
         put
          "proc ucm data = PmTrend.UcmInput_&category._&service noprint;"/
           "id date interval = month;"/
           "model AdjPerCap = &list;"/
           "irregular;"/
           "level;"/
           "slope;"/
           "season length = 12 type = trig;"/
           "estimate;"/
           "forecast lead = &lead outfor = work.UcmSts_&category._&service (keep =  Date adjPercap FORECAST S_NoirReg RESIDUAL STD LCL  UCL  );"/
          "run;";
       run;
        rsubmit;
          %Include "&RemoteProgramPath\MaaProcUcm.sas";
        endrsubmit;
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

	Data PmTrend.UcmSts_&category._&service;  Set PmTrend.UcmSts_&category._&service;
    	if AdjPerCap ne . then Forecast = .;
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
  /* treatment for a given cell ------------------------------------66666666  */
   %if &category = 1720x and &service = 211 %then %do;
      %put NOTE: I am here -------------------------------------------;
	  
      proc sql;
	    update PmTrend.UcmSts_&category._&service
		  set forecast = .,
		      predict = .
		where date<'01Feb2017'd ;
       
		update PmTrend.UcmSts_&category._&service
		  set forecast = 216.46,
		      predict = 216.46
		where date>='01Feb2017'd;

	  quit;
	%end;
   
	/* zxg: treatment for a given cell ------------------------------------zxg  */
   %if &category = 1998x and &service = 777 %then %do;
      %put NOTE: I am here -------------------------------------------;
	  
      proc sql;
       update  PmTrend.UcmSts_&category._&service
       set forecast = (select avg(percap)
                       from PmTrend.Ucminputdata_&category._&service
                       where date between '01Jan2018'd and '01Jan2019'd
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Jan2018'd and '01Jan2019'd
                   )
		where date>='1Feb2019'd;
    
quit;
%end;

	%if &category = 1720x and &service = 571 %then %do;
      %put NOTE: I am here -------------------------------------------;
	  
      proc sql;
	    update PmTrend.UcmSts_&category._&service
		  set forecast = .,
		      predict = .
		where date<='01Feb2019'd ;
       
		update PmTrend.UcmSts_&category._&service
		  set forecast = (3.22+14.59+9.29)/3,
		      predict = (3.22+14.59+9.29)/3
		where date>'01Feb2019'd;

	  quit;
	%end;




	    

	/*zxg: alternative to adjust the lead value due to too many missing value leading to no estimation  */
  /* 1862, 1222, 1330*/
 %if &category = 1330x and &service = 777 %then %do;
 %put NOTE: I am in (&category,&service)++++++++++++++;
   proc sql;

      update PmTrend.UcmSts_&category._&service
		  set forecast = .,
		      predict = .
		where date<='01Feb2019'd ;
     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01May2016'd and '01Feb2019'd and percap is not missing
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01May2016'd and '01Feb2019'd and percap is not missing
                   )
		where date>='01Feb2019'd;
    update  PmTrend.UcmSts_&category._&service as a 
	  set adjPerCap = (select Percap
	                   from PmTrend.Ucminputdata_&category._&service as b
					   where a.date = b.date
					   );

quit;
%end;

%if &category = 1974x and &service = 571 %then %do;
   proc sql;
     update PmTrend.UcmSts_&category._&service
		  set forecast = .,
		      predict = .
		where date<='01Feb2019'd ;

     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Dec2016'd and '01Feb2019'd and percap is not missing
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Dec2016'd and '01Feb2019'd and percap is not missing
                   )
		where date>='01Mar2019'd;
    
quit;
%end;


%if &category = 1974 and &service = 775x %then %do;
   proc sql;
     update PmTrend.UcmSts_&category._&service
		  set forecast = .,
		      predict = .
		where date<'01Feb2019'd ;

     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Dec2016'd and '01Feb2019'd and percap is not missing
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Dec2016'd and '01Feb2019'd and percap is not missing
                   )
		where date>='01Feb2019'd;

	update  PmTrend.UcmSts_&category._&service as a 
	  set adjPerCap = (select Percap
	                   from PmTrend.Ucminputdata_&category._&service as b
					   where a.date = b.date
					   );
    
quit;
%end;

	/*zxg: alternative to adjust the lead value due to too many missing value leading to no estimation  */
 %if &category = 1862x and &service = 671 %then %do;
   %put NOTE: i am in cell (&category,&service);
   proc sql;
     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date >= '01jan2016'd and percap is not missing
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date >= '01jan2016'd and percap is not missing
                   )
		where date>='1Mar2019'd;
    
quit;
%end;

%if &category = 1981 and &service = 776x %then %do;
   %put NOTE: i am in cell (&category,&service);
   proc sql;
     update PmTrend.UcmSts_&category._&service
		  set forecast = .,
		      predict = .
		where date<='01Feb2019'd ;

     update  PmTrend.UcmSts_&category._&service
      set forecast = (select sum(percap)/12
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01jan2019'd and '01feb2019'd and percap is not missing
                   ),
		predict = (select sum(percap)/12
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01jan2019'd and '01feb2019'd and percap is not missing
                   )
		where date>='1Mar2019'd;

	  update  PmTrend.UcmSts_&category._&service as a 
	  set adjPerCap = (select Percap
	                   from PmTrend.Ucminputdata_&category._&service as b
					   where a.date = b.date
					   );
    
quit;
%end;


%if &category = 1861 and &service = 751x %then %do;
   %put NOTE: i am in cell (&category,&service);
   proc sql;
     update  PmTrend.UcmSts_&category._&service
      set forecast = 0,
		predict = 0
		where date>='1Mar2019'd;
	 update  PmTrend.UcmSts_&category._&service as a 
	  set adjPerCap = (select Percap
	                   from PmTrend.Ucminputdata_&category._&service as b
					   where a.date = b.date
					   );
    
quit;
%end;


 %if &category = 1480 and &service = 453x %then %do;
 %put NOTE: i am in cell (&category,&service);
   proc sql;
     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where percap is not missing 
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where percap is not missing 
                   )
		where date>='1Mar2019'd;
    update  PmTrend.UcmSts_&category._&service as a 
	  set adjPerCap = (select Percap
	                   from PmTrend.Ucminputdata_&category._&service as b
					   where a.date = b.date
					   );

quit;
%end;

%if &category = 1280x and &service = 453 %then %do;
   %put NOTE: i am in cell (&category,&service);
   proc sql;
     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Nov2016'd and '01Feb2019'd and percap is not missing
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Nov2016'd and '01Feb2019'd and percap is not missing
                   )
		where date>='1Dec2017'd;
	 
    
quit;
%end;


%if &category = 1330x and &service = 453 %then %do;
   %put NOTE: i am in cell (&category,&service);
   proc sql;
     update  PmTrend.UcmSts_&category._&service
      set forecast = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Jun2016'd and '01Feb2019'd and percap is not missing
                   ),
		predict = (select avg(percap)
                    from PmTrend.Ucminputdata_&category._&service
					where date between '01Jun2016'd and '01Feb2019'd and percap is not missing
                   )
		where date>='01Mar2019'd;
	 
    
quit;
%end;

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

    /*(SC)Copy the pdf over to the U:drive*/
   options noxwait noxsync;


    /*(SC)keep*/
/*    X copy 	"&pDPTrendGraph.S_&fCycle._&service._&category._Afrs&pdatacycle..pdf" */
/*				"&Udrive.S_&fCycle._&service._&category._Afrs&pDataCycle.__%unquote(%sysfunc(datetime(),mydtfmt.)).pdf" /Y;*/

/*   %ExportToExcelFile(ExternalFile=&pDPTrendGraph.S_&fCycle._&service._&category._Afrs&pDataCycle..xls,*/
/*                      InputFullDsn=PmTrend.UcmSts_&category._&service,Sheet=ModelData*/
/*                      ); */

   * Copy the Model Data created above to the U:drive;
/*   %ExportToExcelFile(ExternalFile=&Udrive.S_&fCycle._&service._&category._Afrs&pDataCycle..xls,*/
/*                      InputFullDsn=PmTrend.UcmSts_&category._&service,Sheet=ModelData*/
/*                      ); */

    %put NOTE:(SC) End Create an Excel table of the Model Data withOUT formatting,
								making it easier for users to see and understand the file contents;



     %put &service &category &pforcycle &fcycle &pdatacycle &ResultsTableName;

    /*(SC)Export the Excel file as above, but with formatting to make the data more polished and easier to review*/
    /*(SC)This output will display a better professionalism*/
    /*(SC)Note that the dummy variables are not included. The ods method cannot keep up with changing variables,
	  If someone wants to see the dummy variables, then the former unformatted Excel file is still produced*/
  

   options	LeftMargin = .50in RightMargin =.50in TopMargin =.50in BottomMargin	= .80in;
   ** Determine File Name *****************************************************;
  /*  ODS tagsets.excelxp	
    file="&xml.\S_&fCycle._&service._&category._Afrs&pDataCycle..xml"*/
     style=statistical;


   /******** ModelData sheet *******
   ODS tagsets.excelxp
   options (sheet_name='ModelData' orientation='landscape' zoom='75' scale='80' center_horizontal='no' 	index='no'
		    print_footer='&amp;L &amp;A &#13; &amp;C &amp;F &#13; &amp;R Page &amp;P of &amp;N Pages '			
		    print_header=''  frozen_headers="no"   gridlines="yes"   autofit_height='yes' frozen_headers='yes'
		    autofit_height="yes"
		    );
  */
   

   Proc Print data=PmTrend.UcmSts_&category._&service noobs label
		 Style(Header)=[background=#ccffcc /*light green*/ just=center] 
		 label width=minimum split='*'; Title " "; 


     var Date / style(column)={background=#ccffcc /*lightgreen*/ };       
     var adjPercap forecast priorpercap / style(column)=[cellwidth=1.00in  tagattr="format:$#,###.00"]; 
     var Residual;
     var STPriorPerCap / style(data)=[cellwidth=1.40in  tagattr="format:0.0000"]; /* newly added */
     var STD LCL UCL / style(data)=[cellwidth=1.10in  tagattr="format:0.0000"];

     label adjPercap='Actual * PerCap';	  
  	 label forecast='Predicted * PerCap';
  	 label residual='Series * Residuals';
  	 label std='Forecast*Standard*Errors';
  	 label lcl='Forecast* Lower * Confidence* Limit';
  	 label ucl='Forecast*Upper * Confidence*Limit';


    Quit;

   ods tagsets.excelxp close;
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

