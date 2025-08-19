/*
~ METHOD_NAME                      - FMAPBaseData
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - String 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - FMAPBaseData
~ METHOD_DESCRIPTION               - FMAPBaseData
~ PARAMETER_NAME                   - category service LastDate ForecastStart
~ PARAMETER_VALUE                  - NULL NULL NULL NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/
%MACRO FMAPBaseData(category, Service, LastDate, ForecastStart);
%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   BEGIN FMAPBaseData;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

%LOCAL NLag i k j LastDate BaseFmapValue;

%LET Nlag=%EVAL(&pLagLength+1);

	DATA ThisBaseFmap;
		SET FMAP.BaseFmapFact(WHERE=(category="&category" AND Service="&service")) END=eof;
		IF eof THEN DO;
			CALL SYMPUT("LastDate", PaymentMonth);
			CALL SYMPUT("BaseFmapValue", BaseFmapValue);
			FORMAT PaymentMonth MONYY7.;
		END;	
	RUN;

%PUT NOTE:(SD) LastDate is: &lastDate;

%IF &lastDate = %THEN %DO;
	PROC SQL NOPRINT;
		INSERT INTO FMAP.FmapRatioError(category, Service, RatioERROR)
		VALUES("&category", "&Service", "NO Data");
	QUIT;
%END;
%ELSE %DO;	
	DATA addDate(drop=j);

		DO j=1 TO &Nlag;
			ForecastVersionID="A&pDataCycle";
			category="&category";
			service="&service";
			PaymentMonth=INTNX('MONTH', &lastDate, j);
			BaseFmapValue=&BaseFmapValue;
			TimeStamp=dateTime();
			FORMAT PaymentMonth MONYY7. TimeStamp DateTime20.;
			OUTPUT;
		END;	
	RUN;	
    

	PROC APPEND BASE=ThisBaseFmap DATA=addDate;
	RUN;

	DATA tempFmap0 tempAccuFmap0;
		SET ThisBaseFmap;
	RUN;

	%DO k=1 %TO &Nlag;

		PROC SQL NOPRINT;
			CREATE TABLE tempFmap&k AS
			SELECT ForecastVersionID,
					INTNX('MONTH', PaymentMonth, -1) AS PaymentMonth,
					category,
					Service,
					BaseFmapValue,
					Timestamp
			FROM tempFmap%EVAL(&k-1);
		QUIT;

		PROC SQL NOPRINT;
			CREATE TABLE tempAccuFmap&k AS
			SELECT a.*,
					b.BaseFmapValue AS BaseFmapValue&k,
					b.Timestamp
			 FROM tempAccuFmap%EVAL(&k-1)(DROP=TimeStamp) AS a
			 LEFT JOIN tempFmap&k AS b
			 ON a.ForecastVersionID = b.ForecastVersionID AND
			 	a.PaymentMonth = b.PaymentMonth AND
				a.category = b.category AND
				a.service = b.Service
			ORDER BY a.ForecastVersionID, a.PaymentMonth;
		QUIT;

	%END;


	  DATA BaseFmapFmap;
		SET tempAccuFmap&Nlag(WHERE=(PaymentMonth <= &lastDate)); /* i am here */
		RUN;

	PROC SQL NOPRINT;
		CREATE TABLE FMAP.FmapMos&category._&service AS
		SELECT a.*, b.*
		FROM BaseFmapFmap AS a, 
        FMAP.PctExpenditure(WHERE=(ExpenditureCategoryMcFfs="&category" AND
										BoAfrsService="&service")) AS b;
	QUIT;


	DATA FMAP.FmapMos&category._&service;
		SET FMAP.FmapMos&category._&service(RENAME=(BaseFmapValue=BaseFmapValue0));
		ARRAY baseFmapValue {*} BaseFmapValue0-BaseFmapValue&Nlag;
		%IF &Nlag <= 9 %THEN ARRAY Lags {*} Lag_0-Lag_&Nlag;
		%ELSE %IF &Nlag = 10 %THEN ARRAY Lags {*} Lag_0-Lag_9 Lag10;
		%ELSE ARRAY Lags {*} Lag_0-Lag_9 Lag10-Lag&Nlag;;

		FmapMOS=0;	
		DO i=1 TO %EVAL(&Nlag+1);
			FmapMOS=FmapMOS+baseFmapValue(i)*lags(i);
		END;
	RUN;

/*fix problem with declining too much in Dec*/
%if	(&category=1222 and &service=310) or
	(&category=1222 and &service=333) or
	(&category=1221 and &service=333)
%then %do;
	data FMAP.FmapMos&category._&service;
		set FMAP.FmapMos&category._&service;
		LagValue = Lag(FmapMOS);
			if PaymentMonth = '01DEC16'd then FmapMOS = LagValue;
			if PaymentMonth = '01DEC17'd then FmapMOS = LagValue;
			if PaymentMonth = '01DEC18'd then FmapMOS = LagValue;
		drop LagValue;	
	run;
%end;

/*fix problem with declining too much in Nov and Dec*/
%if (&category=1222 and &service=211) or
	(&category=1222 and &service=221) or
	(&category=1222 and &service=290) or
	(&category=1222 and &service=375) or	
	(&category=1221 and &service=671) or
	(&category=1221 and &service=310) or
	(&category=1221 and &service=211)
%then %do;
	data FMAP.FmapMos&category._&service;
		set FMAP.FmapMos&category._&service;
		LagValue = Lag(FmapMOS);
			if PaymentMonth = '01NOV16'd then FmapMOS = LagValue;
			if PaymentMonth = '01DEC16'd then FmapMOS = LagValue;
			if PaymentMonth = '01NOV17'd then FmapMOS = LagValue;			
			if PaymentMonth = '01DEC17'd then FmapMOS = LagValue;
			if PaymentMonth = '01NOV18'd then FmapMOS = LagValue;				
			if PaymentMonth = '01DEC18'd then FmapMOS = LagValue;
		drop LagValue;	
	run;
%end;		
	
/*Create the table from which the MOS GPlot graphs are determined*/
	PROC SQL NOPRINT;
		CREATE TABLE FMAP.FmapRatio&category._&service AS
		SELECT a.ForecastVersionID, 
				a.PaymentMonth AS MOS FORMAT=MONYY7.,
				a.BaseFmapValue0 AS BaseFmap,
				a.FmapMOS,
				b.FedShareValue,
				COALESCE(b.FedShareValue/a.FmapMOS, 1) AS FmapRatio
		FROM FMAP.FmapMOS&category._&service AS a
		LEFT JOIN Fmap.Hist_FedShare(WHERE=(AfrsCycle="&pDataCycle" /*AND Scheme_ID="&Scheme"*/ 
						AND ForecastMeg="&category" 
						AND ForecastSvc="&service" )) AS b
		ON a.PaymentMonth = MDY(b.ServiceMonth-100*INT(b.ServiceMonth/100), 1, INT(b.ServiceMonth/100))
		ORDER BY a.ForecastVersionID, a.PaymentMonth;
	QUIT;
%END;

/*************HARD CODE OVERRIDES*********************************/
/*		%IF &FCycle=Oct2017 %THEN %DO;
			%IF &category ~= 1960 AND &service = 101 %THEN %DO;      
				%let months = intck('month',"&FirstDateOfAcutalData.","&LastDateOfProjectedData.");
				
				data FMAP.FmapRatio&category._&service;
					do m = 0 to &months.; 
						mos = intnx('month',"&start_date."d,m,'s');                            
						output; 
					end; 
					format
					mos date9.;
					drop m;
				run;
				
				Data FMAP.FmapRatio&category._&service;
					set FMAP.FmapRatio&category._&service;
					ForMeg=&category;
					ForSvc=&service;
					ForecastVersionID=&Scheme || &pDataCycle;
					BaseFmap=.5;
					FmapMOS=.5;
					Zero=0;
					ONE=1;
					FedShareValue=.5;
					FmapRatio=1;
					Projected=1;
					ProjectedFmap=.5;
				run;
			%end;
		%end;*/
/*************END HARD CODE OVERRIDES*********************************/				


/* Prepare to assess whether the Ratio file is populated or not. This is to set code to
	populate an unpopulated (read, no expenditures) a Cell, so that it will create a pseudo
	populated FMAP-Ratio file, and create a GPlot graphic*/
Proc SQL noprint;
Select count(*)
	into :OBSCOUNT
From Fmap.FmapRatio&category._&service;
Quit;

%put &OBSCOUNT;

/* If the Fmap file is unpopulated (obscount=0), then this code will run, otherwise it will be skipped*/
%IF &OBSCOUNT = 0 %THEN %DO;
Data Fmap.FmapRatio&category._&service; 
    Set Fmap.Dumster; 
	ForecastVersionID="A&pDataCycle";
	*CatName = &ForMegName;	/*Will be added later*/
	*SerName = &ForSvcName;	/*Will be added later*/
Run;
%END;

/*create the table used for the forecast*/
DATA FmapRatio&category._&service.Truncate;
	SET FMAP.FmapRatio&category._&service.(where=(mos >= &ForecastStart));
RUN;

/* Back to code that should run if the Fmap-Ratio file was populated*/



%PUT ;
%PUT NOTE:(SD)*************************************************************************;
%PUT NOTE:(SD)                   END of FMAPBaseData;
%PUT NOTE:(SD)*************************************************************************;
%PUT ;


%MEND;

/*
%MethodRegistration(&pFMAP, FMAPBaseData);
*/
/*
%FMAPBaseData(category=1040, service=005);
*/
