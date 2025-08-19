/*
~ METHOD_NAME                      - ForecastFmap
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - String 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - ForecastFmap
~ METHOD_DESCRIPTION               - Forecast Fmap
~ PARAMETER_NAME                   - NewExcelTable test ForecastStart 
~ PARAMETER_VALUE                  - NO YES NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/

%MACRO ForecastFmap(NewExcelTable, Test, ForecastStart);
%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   BEGIN ForecastFmap;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

%IF &GraphStart= %THEN %LET ThisGraphStart=&ForecastStart;
%ELSE %LET ThisGraphStart=%SYSFUNC(min(&GraphStart, &ForecastStart));

%LOCAL dsid RC;



/* JN: &test is currently set to NULL in RunFMAP using the &PassParameter1 variable*/
%IF %UPCASE(&test) = YES OR %UPCASE(&test) = Y %THEN %LET dsid=%SYSFUNC(OPEN(FMAP.ForecastPTmodelsCurrent(WHERE=(UPCASE(test)='X'))));
%ELSE %LET dsid=%SYSFUNC(OPEN(FMAP.ForecastPTmodelsCurrent));

%DO %WHILE(%SYSFUNC(FETCH(&dsid)) = 0);
	%LET category=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, category))));
	%LET service=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, service))));
	%LET ModelType=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, ModelType))));
	%LET FmapModelType=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, FmapModel))));
	%LET FirstDate=%SYSFUNC(GETVARN(&dsid, %SYSFUNC(VARNUM(&dsid, FirstDate))));
	%LET LastDate=%SYSFUNC(GETVARN(&dsid, %SYSFUNC(VARNUM(&dsid, LastDate))));
	%LET Special=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, SpecialTreatment))));
	%let ForecastStart=%SYSFUNC(GETVARN(&dsid, %SYSFUNC(VARNUM(&dsid, ForecastStart))));
	
	%if &ModelType = L %then %let ModelTypeFull=Large Cell;
	%else %let ModelTypeFull=Small Cell;
	
	/*%let JumpOff=%SYSFUNC(intnx(month, &LastDate, 1));*/

	%PUT NOTE: (SD)  Category: &category   Service: &Service  FmapModelType: &FmapModelType FirstDate: &FirstDate LastDate: &LastDate ForecastStart: &ForecastStart;
	
	/*create a data table to add vertical reference lines for the jump off point and forecast start*/
	data anno;
		  length function color $ 8;
		  /* Vertical reference lines */
		  do x=&JumpOff to &FirstDateOfProjectedData by (&FirstDateOfProjectedData-&JumpOff);
				function='move'; xsys='2'; ysys='1';
				y=0; output;

				function='draw'; xsys='2'; ysys='1';
				size=3; line=2; color='graycc'; y=100; output;
			end;
	run;	
	


/*++++++++++++++++++JN: Following code is only if the ModelType is Forecast++++++++++++++++++*/
	%IF %UPCASE(&FmapModelType) = FORECAST %THEN %DO;
		%LET lead=%SYSFUNC(INTCK(MONTH, &LastDateOfAcutalData, &LastDateOfProjectedData));
		%PUT NOTE: (SD) The Lead period is: &lead;

     %put &Lead;

    PROC FORECAST DATA=FMAP.FmapRatio&category._&service(WHERE=(&FirstDate <= MOS <= &LastDateOfAcutalData)) 
	  OUT=FmapPredall OUTFULL
	  INTERVAL=MONTH
	  OUTEST=FmapEst&category._&service
	  OUTFITSTATS
	  LEAD=&LEAD;
	  ID MOS;
	  VAR FmapRatio;
   RUN;




    dm 'odsresults; clear;'; 		*Clear the Results Window;

		DATA FmapPred;
			SET FmapPredall(WHERE=(_TYPE_="FORECAST" AND _LEAD_ >0));
		RUN;

		DATA Projected;
			SET FmapPredall(WHERE=(_TYPE_="FORECAST"));
		RUN;

		DATA _TempFmap(DROP=_TYPE_ _LEAD_);
			UPDATE FMAP.FmapRatio&category._&service FmapPred;
			BY MOS;
		RUN;

		PROC SQL;
			CREATE TABLE FMAP.FmapRatio&category._&service AS
			SELECT a.*, COALESCE(b.FmapRatio, 0) AS ProjectedFmapRatio
			FROM _TempFmap AS a
			LEFT JOIN Projected AS b
			ON a.MOS = b.MOS
			ORDER BY a.MOS;
		QUIT;

*Insert conversion ratio =1 here;
%SetConversionRatio1(&Category, &Service, FORECAST);



 DATA FMAP.FmapRatio&category._&service;	
   SET FMAP.FmapRatio&category._&service;
   ProjectedFmap=FmapMOS*ProjectedFmapRatio;
   IF MOS > &LastDateOfAcutalData THEN FmapRatio=ProjectedFmapRatio;
   IF MOS > &LastDateOfAcutalData THEN FedShareValue=FmapMOS*FmapRatio;
 RUN;
%END;
/*++++++++++++++++++JN: End of Forecast code  - TYPICALLY NOT USED ++++++++++++++++++*/
	
/*++++++++++++++++++JN: This calls the main Forecast program++++++++++++++++++*/	
	%ELSE %IF %UPCASE(&FmapModelType) = AVERAGE %THEN %DO;
		%IF %UPCASE(&special) = X %THEN %DO;
			%SpecialFmapForecastAverage(category=&category, service=&service, FirstDate=&FirstDate, LastDate=&LastDate);
		%END;
		%ELSE %DO;
			%FmapForecastAverage(category=&category, service=&service, FirstDate=&FirstDate, LastDate=&LastDate);
		%END;
	%END;
	%ELSE %PUT ERROR:(SD) The Fmap Forecast model is WRONG!;
/*
	PROC DATASETS LIBRARY=FMAP NOLIST;
		CHANGE FmapRatio&category._&service=ZFmapRatio&category._&service;
	RUN;
*/

/*####################################################################################################*/
/*Limit ACA Expansion to .93 in CY2019 IN JAN2019*/
%if (&category=1221 and &service=671) or
	(&category=1222 and &service=771)
%then %do;
	data FMAP.FmapRatio&category._&service;
		set FMAP.FmapRatio&category._&service;
			if mos >= '01JAN19'd then FedShareValue = Min(0.93, FedShareValue);
	run;
%end;

/*Limit ACA Expansion to .93 in CY2019 IN FEB2019*/
%if (&category=1221 and &service=336) or 
	(&category=1221 and &service=350) or 
	(&category=1221 and &service=610) or
	(&category=1221 and &service=630) or
	(&category=1221 and &service=211) or
	(&category=1222 and &service=221)
%then %do;
	data FMAP.FmapRatio&category._&service;
		set FMAP.FmapRatio&category._&service;
			if mos >= '01FEB19'd then FedShareValue = Min(0.93, FedShareValue);
	run;
%end;
/*END SPECIAL ACA PATCH*/
/*####################################################################################################*/

	DATA FMAP.zFmapRatio&category._&service(DROP=CurrentFedShare CurrentFmapRatio);
		SET FMAP.FmapRatio&category._&service;
	RUN;

	PROC SQL NOPRINT;
		CREATE TABLE FMAP.FmapRatio&category._&service as
		SELECT a.*                                                      /*fixed by ZXG on 12/6/2017*/
		FROM FMAP.ZFmapRatio&category._&service AS a
		LEFT JOIN Fmap.Hist_fedShare(WHERE=(AfrsCycle="&pDataCycle" AND ForecastMeg="&category" AND
												ForecastSvc="&service")) AS b
		ON /* SUBSTR(a.ForecastVersionID, 6, 1) = b.Scheme_ID AND */
			a.MOS = MDY(b.ServiceMonth-100*INT(b.ServiceMonth/100), 1, INT(b.ServiceMonth/100))
		ORDER BY a.ForecastVersionID, a.MOS;
	QUIT;



/*%Let Category = 1480;	
%Let Service = 375;		
%Let FmapModelType = Average;
%Let ModelType = S;*/


/* Add Meg-Category and Service names to the file for later use in the GPlot code*/
/*These two files identify each MEG and Service number*/
/*Keep only 2 variables of each file to match to the fmap (ratio) file*/
Proc Sort data=MainDM.Dim_for_MEG out=MEG1 (keep=ForMeg ForMegName); by ForMeg; Run;
Proc Sort data=MainDM.Dim_for_Svc out=Svc1 (keep=ForSvc ForSvcName); by ForSvc; Run;


Data MEG2; length ForMegName1 $48.; Set MEG1; 
	ForMegName1=ForMegName;
	drop ForMegName;
Run;
Data MEG; length ForMegName $48.; Set MEG2;
	ForMegName=strip(ForMegName1);
	drop ForMegName1;
Run;

Data SVC2; length ForSvcName1 $56.; Set SVC1; 
	ForSvcName1=ForSvcName;
	drop ForSvcName;
Run;
Data SVC; length ForSvcName $56.; Set SVC2;
	ForSvcName=strip(ForSvcName1);
	drop ForSvcName1;
Run;

* Characterize the variables to match to the MainDM files to add the Meg and Service description;
Data Z1; 	length ForMeg $4. ForSvc $3.;  Set FMAP.FmapRatio&category._&service;
	ForMeg=&Category;
	ForSvc=&Service;
	*drop ForMegName ForSvcName;
Run;

Proc Sort data=z1 out=z2; by ForMeg; Run;

* Add the definition of the category;	
Data z3; merge z2 (in=a) Meg;
		by ForMeg;
		if a;
Run;

Proc Sort data=z3 out=z4; by ForSvc; Run;
	
* Add the definition of the Service;
Data z5; merge z4 (in=a) Svc;
		by ForSvc;
		if a;
Run;

* Macroize the definition to Meg and Service;
Data _Null_;  Set z5;
	Call symput ('ForMegName',ForMegName);
	Call symput ('ForSvcName',ForSvcName);
Run;

%put &ForMegName;
%put &ForSvcName;

* After adding Meg and Service names to the z file, over-write the existing
	Ratio file;
Data FMAP.FmapRatio&category._&service; Set z5; Run;




/*Change in sChip fund allocation beginning October 2015*/
/*Attempt to set predicted values Oct2015 forward to 88% Federal*/
/*			%IF (&category = 1861 or &category = 1862) %THEN %DO;
				Data FMAP.FmapRatio&category._&service;		Set z5;
						IF MOS GE &sCHIP THEN DO;
							BaseFmap=.88;
							FmapMOS=.88;
							FedShareValue=.88;
							ProjectedFmap=.88;
						END;
				Run;
				%PUT NOTE:(SD) Special Funding ReAllocation for Category 1861-1862;
			%END;*/


DATA FMAP.Result_Fedshare;  
  SET FMAP.Result_Fedshare;
  IF ForecastVersionID = "A&pDataCycle" AND
 	 ForecastMeg = "&category" AND
	 ForecastSvc = "&service" THEN Delete;
RUN;

 DATA FMAP.PredResult_Fedshare;  
   SET FMAP.PredResult_Fedshare;
	IF ForecastVersionID = "A&pDataCycle" AND
			ForecastMeg = "&category" AND
			ForecastSvc = "&service" THEN Delete;
 RUN;

 PROC SQL NOPRINT;
		INSERT INTO FMAP.Result_Fedshare(ForecastVersionID, ForecastMeg, ForecastSvc, ServiceMonth, ForecastMosFedShare, ForecastConversionRatio)
		SELECT ForecastVersionID, "&category" AS ForecastMeg, "&service" AS ForecastSvc, 
				MOS AS ServiceMonth, FedShareValue AS ForecastMosFedShare, FmapRatio AS ForecastConversionRatio
		FROM FMAP.FmapRatio&category._&service;
	QUIT;

/*This is the file that is utilized in RunFmap.sas just prior to the %StateFundSplit macro*/
	PROC SQL NOPRINT;
		INSERT INTO FMAP.PredResult_Fedshare(ForecastVersionID, ForecastMeg, ForecastSvc, ServiceMonth, 
					ForecastMosFedShare, ForecastConversionRatio)
		SELECT ForecastVersionID, "&category" AS ForecastMeg, "&service" AS ForecastSvc, 
				MOS AS ServiceMonth, ProjectedFmap AS ForecastMosFedShare, ProjectedFmapRatio AS ForecastConversionRatio
		FROM FMAP.FmapRatio&category._&service;
	QUIT;

%DropTable(FMAP.zFmapRatio&category._&service);


   %let timenow=%sysfunc(time(), time.);			/* Set up timestamp under title in the graphic. */
   %let datenow=%sysfunc(date(), date9.);
   
proc export 
  data=FMAP.FmapRatio&category._&service 
  dbms=csv
  outfile="&Expo\FmapRatio&category._&service..csv"
  replace;
run;   


dm 'odsresults; clear;'; 		*Clear the Results Window;
dm "output; clear; out; clear;"



***************************************************************************
*** BEGIN pdf Proc GPLOT Graphic coding *******************************************;

/*Create new table only used for graphing*/
Data FmapRatio&Category._&Service._Graph (rename=(mos=MonthofService FedShareValue=FedShare ProjectedFmapRatio=ProjFmapRatio)); 
Set Fmap.FmapRatio&Category._&Service(where=(mos >= &ThisGraphStart));
	UpperY = min(max(FedShareValue, FmapMOS, BaseFmap, ProjectedFmap) + 0.03, 1);
	LowerY = max(min(FedShareValue, FmapMOS, BaseFmap, ProjectedFmap) - 0.03, 0);
Run;

proc sql noprint;
		SELECT count(*) INTO: NSOF
		FROM DistinctSoF_&category._&service.;
quit;

***************************************************************************
*** Proc GPLOT Graphic coding description*******************************************;
/* Symbol1 is used to delimit the 100% and the 0% limits in the graph. The dots that would represent
	month/year are determined as none, and the color of the line is the same as all the other
	horizontal lines, so that they appear as the same as the other horizontal lines
	The greened out sections of the gplot code are stats data that just clutter the graphic. They are 
	left in, in case they are ever needed again
	The footnotes are greened out, because the Legend looks better to describe the graphic depictions*/

/*%Let ModelType=L;
%Let category=1222;
%Let service=410;*/

/**********mop graphs***********/
ODS LISTING CLOSE;
	ODS PDF FILE="&pDMopGraphs.BaseFmap_SOF_&category._&service..pdf" STYLE=SASWEB;
%macro mop;
	/*open the table and loop through the records grabbing the cpt code until EOF*/
	%LET Mdsid=%SYSFUNC(OPEN(DistinctSoF_&category._&service.));
		
	%DO %WHILE (%SYSFUNC(FETCH(&Mdsid)) = 0);
		%LET sofID=%SYSFUNC(GETVARN(&Mdsid, %SYSFUNC(VARNUM(&Mdsid, sof))));
		%LET sofName=%SYSFUNC(GETVARC(&Mdsid, %SYSFUNC(VARNUM(&Mdsid, AfrsSofName))));
		%LET sof=%SYSFUNC(GETVARC(&Mdsid, %SYSFUNC(VARNUM(&Mdsid, AfrsSof))));
					
		Title1 j=l c=brown  h=1.75 c=blue  "                                                                   Source Of Fund &sof = &sofName";
		Title2 j=l c=brown  h=1.25 c=blue  "                                                                                              Service  &service = &ForSvcName" ;
		Title3 j=l c=brown  h=1.25 c=blue  "                                                                                              Category &category = &ForMegName" ;
		Title4 j=l  h=1.25 c=blue  "                                                                                              &ModelTypeFull" ;
		
		Footnote1 justify=center  c=blue h=1.00 "OFM Forecasting and Research";
		Footnote2 justify=center  c=blue /*ls=0.25*/ h=1.00 "(&datenow &timenow)" f='Times New Roman' ;


		SYMBOL1 c=black 	v='A' 	i=spline;
		SYMBOL2 c=red		v='F' 	i=Spline;
		SYMBOL3 c=white 	v='' 		i=Spline;
		SYMBOL4  h=0.25 v=none 	C=GRAYCC i=SOLID;

	Legend1 Label=(Height=1 Position=top justify=left 'Legend')
		value=("Weights" "Predicted Value of Weights" "" "")
		across=2
		down=3;
	
	/*truncate the dates for the graph*/
	Data BaseFmap_&category._&service._SOF_&sofID.; 
		Set BaseFmap_&category._&service._SOF_&sofID.(where=(mop >= &ThisGraphStart));
	run;		

	Proc GPlot data=BaseFmap_&category._&service._SOF_&sofID.;
			Plot 
					Weights*MOP=1 
					Predicted*MOP=2
					UpperY*MOP=4
					LowerY*MOP=4					
			/Overlay 
					cframe=lightYellow
					/*href=&FirstDateOfAcutalData &LastDateOfAcutalData*/
					autovref cvref=graycc							/*Set up reference horizontal lines */
					autohref chref=graycc							/*Set up reference vertical lines*/		
					Legend=Legend1
					annotate=anno;
					
					format Weights Predicted UpperY LowerY percent7.2;
			Run;

	ods escapechar='~';
	Title1 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   Source Of Fund &sof = &sofName";
	Title2 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   Service  &service = &ForSvcName" ;
	Title3 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   Category &category = &ForMegName" ;
	Title4 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   &ModelTypeFull" ;	

		%if &NSOF > 1 %THEN %DO;
			PROC PRINT DATA=Fit_&category._&service._SOF_&sofID.; 
			PROC PRINT DATA=Parameters_&category._&service._SOF_&sofID.;
		RUN;
		%end;

	PROC PRINT DATA=BaseFmap_&category._&service._SOF_&sofID.(DROP=Zero UpperY LowerY);		/*The data represented by the graphic*/
	RUN;

	%END;

	%LET RC=%SYSFUNC(CLOSE(&Mdsid));
%mend mop;
%mop;

	Quit; 			


	ODS PDF CLOSE;
	ODS LISTING;
/***********end of mop graphs***********/

	GOPTIONS RESET=ALL CBACK=lightBlue;
	OPTIONS ORIENTATION=LANDSCAPE nodate nonumber;

   %let timenow=%sysfunc(time(), time.);			/* Set up timestamp under title in the graphic. */
   %let datenow=%sysfunc(date(), date9.);
   
	SYMBOL1  h=0.25 v=none 	C=GRAYCC i=SOLID;
	SYMBOL2  h=0.50 v=dot 		C=BLUE 		i=SPLINE;
	SYMBOL3  h=0.95 v=dot 		C=GREEN 	i=SPLINE;
	SYMBOL4  h=0.70 v=square 	C=RED 		i=SPLINE		width=2;	/*width=thickness of the joining line*/
	SYMBOL5  h=0.50 v=dot 		C=Yellow 	i=SPLINE;
	SYMBOL6  h=0.50 v=dot 		C=PURPLE 	i=SPLINE;

	ODS LISTING CLOSE;
	ODS PDF FILE="&pDMosGraphs.&ModelType._&FCycle._Fmap_&service._&category._Afrs&pDataCycle..pdf" STYLE=SASWEB;
	*ODS PDF FILE="&pDMosGraphs.&ModelType._Fmap_&service._&category..pdf" STYLE=SASWEB;
/*Above line works, however line below adds a timestamp*/
	*ODS PDF FILE="&pDMosGraphs.&ModelType._Fmap_&category._&service.__%unquote(%sysfunc(datetime(),mydtfmt.)).pdf" STYLE=SASWEB;


		Title1 j=l  h=1.75 c=blue  "                                                                   FMAP Related Variables";
		Title2 j=l  h=1.25 c=blue  "                                                                                              Service  &service = &ForSvcName" ;
		Title3 j=l  h=1.25 c=blue  "                                                                                              Category &category = &ForMegName" ;
		Title4 j=l  h=1.25 c=blue  "                                                                                              &ModelTypeFull" ;
		
		Footnote1 justify=center  c=blue h=1.00 "OFM Forecasting and Research";
		Footnote2 justify=center  c=blue /*ls=0.25*/ h=1.00 "(&datenow &timenow)" f='Times New Roman' ;

	Legend1 Label=(Height=1 Position=top justify=left 'Legend')
			value=("Base Fmap" "Fmap MOS" "Fed Share Value" "Projected FMAP" "" "")
			across=4
			down=3;

	Proc GPlot data=FmapRatio&category._&service._Graph;
		axis1 label=(angle=90 "FMAP"); 
		axis2 label=("Month of Service");
		PLOT 	
				BaseFmap*MonthofService=3
				FmapMOS*MonthofService=6
				FedShare*MonthofService=2				
				/*CurrentFedShare*MonthofService=6*/
				ProjectedFmap*MonthofService=4				
				UpperY*MonthofService=1
				LowerY*MonthofService=1
				

		/OVERLAY 
				vaxis = axis1
				haxis = axis2
				CFRAME=LightYellow								/*Set up inside of graph this color*/
				autovref cvref=graycc							/*Set up reference horizontal lines */
				autohref chref=graycc							/*Set up reference vertical lines*/
				Legend=Legend1
				annotate=anno;
				
		Note h=1.25 move=(74,28) pct  'Above Green Line: State Share';		/* Anything to the south of the line is State share*/
		Note h=1.25 move=(74,25) pct  'Below Green Line: Federal Share';	/* Anything to the north of the line is Federal share*/
		
		format FedShare FmapMOS BaseFmap ProjectedFmap UpperY LowerY percent7.2;


	/*Note h=1.25 move=(8,23) pct "&Category: &X"*/		/* Description of the category, lower left in the graph*/
	/*Note h=1.25 move=(8,20) pct "&Service: &Y"*/		/* Ditto category*/
			Run;

		ods escapechar='~';
		Title1 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   Related Variables";
		Title2 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   Service  &service = &ForSvcName" ;
		Title3 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   Category &category = &ForMegName" ;
		Title4 j=l  h=1.25 c=blue  "~S={asis=on}                                                                                                                                                   &ModelTypeFull" ;
			
Proc Print data=FmapRatio&category._&service._Graph(DROP=ForecastVersionID UpperY LowerY); 	Run;

/*SOF graphs*/
%macro sof;
	/*open the table and loop through the records grabbing the cpt code until EOF*/
	%LET Sdsid=%SYSFUNC(OPEN(DistinctSoF_&category._&service.));
		
	%DO %WHILE (%SYSFUNC(FETCH(&Sdsid)) = 0);
		%LET sofID=%SYSFUNC(GETVARN(&Sdsid, %SYSFUNC(VARNUM(&Sdsid, sof))));
		%LET sofName=%SYSFUNC(GETVARC(&Sdsid, %SYSFUNC(VARNUM(&Sdsid, AfrsSofName))));
		%LET sof=%SYSFUNC(GETVARC(&Sdsid, %SYSFUNC(VARNUM(&Sdsid, AfrsSof))));
					
		Title1 j=l c=brown  h=1.75 c=blue  "                                                                   Source Of Fund &sof = &sofName";
		Title2 j=l c=brown  h=1.25 c=blue  "                                                                                              Service  &service = &ForSvcName" ;
		Title3 j=l c=brown  h=1.25 c=blue  "                                                                                              Category &category = &ForMegName" ;
		Title4 j=l  h=1.25 c=blue  "                                                                                              &ModelTypeFull" ;
		
		Footnote1 justify=center  c=blue h=1.00 "OFM Forecasting and Research";
		Footnote2 justify=center  c=blue /*ls=0.25*/ h=1.00 "(&datenow &timenow)" f='Times New Roman' ;


		SYMBOL1 c=black 	v='A' 	i=spline;
		SYMBOL2 c=red		v='F' 	i=Spline;
		SYMBOL3 c=white 	v='' 		i=Spline;
		SYMBOL4  h=0.25 v=none 	C=GRAYCC i=SOLID;

	Legend1 Label=(Height=1 Position=top justify=left 'Legend')
		value=("Weights" "Predicted Value of Weights" "" "")
		across=2
		down=3;
	
	Proc GPlot data=BaseFmap_&category._&service._SOF_&sofID.;
			Plot 
					Weights*MOP=1 
					Predicted*MOP=2
					UpperY*MOP=4
					LowerY*MOP=4					
			/Overlay 
					cframe=lightYellow
					/*href=&ForecastStart*/
					autovref cvref=graycc							/*Set up reference horizontal lines */
					autohref chref=graycc							/*Set up reference vertical lines*/		
					Legend=Legend1
					annotate=anno;
					
					format Weights Predicted UpperY LowerY percent7.2;
			Run;

	%END;

	%LET RC=%SYSFUNC(CLOSE(&Sdsid));
%mend sof;
%sof;

	Quit; 			
/*end of SOF graphs*/
	
	ODS PDF CLOSE;
	ODS LISTING;


*** END pdf Proc GPLOT Graphic coding ***********************************************;


* Allow some time for the pdf graph output;
* Otherwise all the pdfs back up and are printed after all the FMAP code is complete, this 
	might help to alleviate a potential RAM overload when running all the MEG-Svc combinations;
Data _null_; X=sleep(2,1);	Run;  * Sleep for 1 seconds;


dm 'odsresults; clear;'; 		*Clear the Results Window;
dm "output; clear; out; clear;"

	%IF %UPCASE(&LoadKdrive) = YES %THEN %DO;
      	%SYSEXEC(del "&&&pDB_&service._FMAP.&ModelType._Fmap_&service._&category..pdf"); 
	  	%SYSEXEC(COPY "&pDMosGraphs.&ModelType._Fmap_&service._&category..pdf" "&&&pDB_&service._FMAP");
	%END;
%END;

%LET RC=%SYSFUNC(CLOSE(&dsid));



dm 'odsresults; clear;'; 		*Clear the Results Window;
dm "output; clear; out; clear;"



/*The xml file is probably closed now (when it was used to create the xlsx, now delete it from the folder*/
/*%SYSEXEC(del "&Expo\FmapRatio&category._&service..xml");*/ * Delete XML File;   

/*Alt way to delete a file*/
/*X del "&Expo\FmapRatio&category._&service..xml";*/ 		* Delete XML File;

/*X del "U:\FORECAST\Oct 15 Forecast\QC_Check\Mirror\FMAPs\*.xml"; */		* Deletes ALL XML Files *;


	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   END of ForecastFmap;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

%MEND;

/*return to MOS_FMAP*/

/*
%MethodRegistration(&pFMAP, ForecastFmap);
*/
/*
%ForecastFmap(NewExcelTable=, test=);
*/
