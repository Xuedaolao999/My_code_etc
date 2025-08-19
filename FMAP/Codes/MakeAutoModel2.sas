/*
~ METHOD_NAME                      - MakeAutoModel2
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - string 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - MakeAutoModel
~ METHOD_DESCRIPTION               - Make Automatic Models
~ PARAMETER_NAME                   - category service SOF cutoff LastDate
~ PARAMETER_VALUE                  - NULL NULL NULL NULL NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/

%MACRO MakeAutoModel2(category, service, SOF, Cutoff, LastDate);

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   BEGIN MakeAutoModel2;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

    options symbolgen;

	%GLOBAL AutoDummy comment;

	%LOCAL dsid1 dsid3;

	%LET AC=1.0;
	%LET countIter=1;
	%LET comment=;
	%IF &RegressionStart= %THEN %LET RegressionStart=&Cutoff;



	*Solve 336 issue;
	%IF &Service ~= 336 %THEN 
       %LET ThisLastDateOfAcutalData=&LastDateOfAcutalData;
	/*%ELSE; %LET ThisLastDateOfAcutalData=&LastDate;*/
	%ELSE; 
      %LET ThisLastDateOfAcutalData=%SYSFUNC(INTNX(MONTH, &LastDateOfAcutalData, -2));
	
	/*avoid bad data for 1221-771*/
	/*%IF &FCycle=Oct2017 AND &category=1221 AND &Service=771 %THEN 
	%LET ThisLastDateOfAcutalData=%SYSFUNC(INTNX(MONTH, &LastDateOfAcutalData, -7));*/
	
	/*******************TEST***********************/
	/*%IF &Service ~= 336 %THEN %LET ThisLastDateOfAcutalData=%SYSFUNC(INTNX(MONTH, &LastDateOfAcutalData, -2));
	%ELSE; %LET ThisLastDateOfAcutalData=%SYSFUNC(INTNX(MONTH, &LastDateOfAcutalData, -4));*/	

	%IF &pDataCycle = 1109 AND &Service = 610 %THEN 
	  %LET ThisLastDateOfAcutalData=%SYSFUNC(INTNX(MONTH, &LastDateOfAcutalData, -2));

/*Original greened out. Try to accomodate the eleven SOFs, 12 iterations: stcp*/
	/*%DO %WHILE (&countIter <= 10);*/
	%DO %WHILE (&countIter <= 12);

		%Q1Q3IQR(infile=Ztemp, var=Diffs, category=&category, service=&service, AbnormalCriteria=&AC);
/* ZXG: 
      Create the global variables: Alower, Ahigher, Mlower, Mhigher, Q1, Q3 using table Ztemp which contains the difference of the wights, i.e., the 
	  variable of Diffs. 
*/


     dm 'odsresults; clear;'; 		* Clear the Results Window;
	 %LET AutoDummy=%DummyString3(infile=Ztemp);

	 %PUT NOTE:(SD) The Auto Dummy variable is: |&AutoDummy.|;

		%LET k=1;

		%DO %WHILE(%QSCAN(&AutoDummy, &k, %STR( )) ~= );
			%LET AutoDummy&k =%QSYSFUNC(TRIM(%QSCAN(&AutoDummy, &k, %str( ))));
			%PUT NOTE: (SD) The No. &k Exogenous Variable is: &&AutoDummy&k;
			%LET k=%EVAL(&k+1);
		%END;	

		%PUT NOTE:(SD) k=%EVAl(&k-1);

		%IF &k > 6 %THEN %DO;
			%LET AC=%SYSEVALF(1.2*&AC);
			%LET CountIter=%EVAL(&countIter+1);
			%PUT NOTE:(SD) Too Many dummies, Run again. No.&countIter Iteration;
		%END;
		%ELSE %LET CountIter=100;
	%END;
	
	/*truncate dates*/
	DATA ForecastBaseFmapweightsCS;
		SET ForecastBaseFmapweightsCS(where=(mop >= &RegressionStart));
	RUN;

	%PutDummyAuto2(inFile=ForecastBaseFmapweightsCS, outfile=fcstBFmapDataTemp, category=&category, service=&service);
/* ZXG:
	create the file work.fcstBFmapDataTemp, which contain the data from the input file work.ForecastBaseFmapweightsCS,
	and the dummy variables

	*/


/*TrendMon is a sequential observation, beginning withzero matching to the earliest month-year, 
	and building up by a count of 1 to the lastmost month-year in the dataset*/
	DATA fcstBFmapDataReg fcstBFmapDataTest ;
		SET fcstBFmapDataTemp;
			TrendMon=INTCK("Month", &RegressionStart, MOP);
			IF MOP <= &ThisLastDateOfAcutalData THEN OUTPUT fcstBFmapDataReg;
			ELSE OUTPUT fcstBFmapDataTest;
	RUN;
	
	/*ELSE IF MOP >= &FirstDateOfProjectedData THEN OUTPUT fcstBFmapDataTest;*/

	ODS OUTPUT FitStatistics=Fit_&category._&service._SOF_&sof. ParameterEstimates=parameters_&category._&service._SOF_&sof.;

	%LET dsid1=%SYSFUNC(OPEN(fcstBFmapDataReg, IS));
	%PUT NOTE:(SD) dsid1: &dsid1;
	%IF %SYSFUNC(FETCH(&dsid1)) = 0 %THEN %DO;
		%LET Nobs=%SYSFUNC(ATTRN(&dsid1, NLOBS));
		%PUT NOTE:(SD) There are &nobs data points used for regression;
	%END;

	%LET RC=%SYSFUNC(CLOSE(&dsid1));

	%LET nMons=%EVAL(%SYSFUNC(INTCK(MONTH, &RegressionStart, &ThisLastDateOfAcutalData))+1);

	%LET AdjM=%SYSEVALF(&Nobs/&nMons);
	%PUT NOTE:(SD) The ratio used to adjust missing values is: &AdjM;

	%LET Trend=1;

%put &autodummy;

	PROC REG DATA=fcstBFmapDataReg OUTEST=TempParameters;
	     MODEL Weights= TrendMon &AutoDummy;
		 WEIGHT TrendMon;
		 OUTPUT OUT=TempRed residual=Residual pred=Predicted;
	RUN; QUIT;


	%LET dsid3=%SYSFUNC(OPEN(Parameters_&category._&service._SOF_&sof.(WHERE=(Variable="TrendMon")), IS));
		%IF %SYSFUNC(FETCH(&dsid3)) = 0 %THEN %DO;
			%LET pTrendMon=%SYSFUNC(GETVARN(&dsid3, %SYSFUNC(VARNUM(&dsid3, Probt))));
		%END;
		%ELSE %PUT ERROR:(SD) NO output from the regression model;
	%LET RC=%SYSFUNC(CLOSE(&dsid3));

	%IF &pTrendMon >= 0.05 OR AdjM ~= 1 %THEN %DO; 
		ODS OUTPUT FitStatistics=Fit_&category._&service._SOF_&sof. ParameterEstimates=parameters_&category._&service._SOF_&sof.;
        /*ZXG: if the TrendMon is not significant at 0.05 level, the variable TrendMon should be dropped from the regression model    */
		PROC REG DATA=fcstBFmapDataReg OUTEST=TempParameters;
	    	MODEL Weights=&AutoDummy;
		 	OUTPUT OUT=TempRed residual=Residual pred=Predicted;
		RUN;
		QUIT;


		%LET Trend=0;
	%END;

	%LET N=1;
	%DO %WHILE(%SCAN(&autodummy, &N, %STR( )) ~= %STR( ));
		%LET Dummy&N=%SCAN(&autodummy, &N, %STR( ));
		%PUT NOTE:(SD) The No. &N Dummy is: &&Dummy&N;
		%LET N=%EVAL(&N+1);
	%END;

	%LET m=%EVAL(&N-1);
	%PUT NOTE:(SD) There are total &m dummy variables;

dm 'odsresults; clear;'; 		* Clear the Results Window;


	PROC SQL NOPRINT;
			CREATE TABLE Tempprojected AS
			SELECT 	/*a.Scheme, */
					a.Category,
					a.service,
					a.MOP,
					a.Weights,
					a.TrendMon,
					
					%DO i=1 %TO &m; 
					a.&&Dummy&i,
					%END;

					b.intercept,
					%IF &Trend = 1 %THEN b.TrendMon; %ELSE 0; AS coTrendMon ,
					
					%DO i=1 %TO &m; 
					b.&&Dummy&i AS E&&Dummy&i,
					%END;

					&adjM*(b.intercept+(%IF &Trend = 1 %THEN b.TrendMon; %ELSE 0;)*a.TrendMon %DO i=1 %TO %EVAL(&m); + a.&&dummy&i*b.&&dummy&i %END;) AS Predicted,
					a.Weights-calculated predicted AS RESIDUAL 
			 FROM fcstBFmapDataTest AS a, Tempparameters AS b;
		QUIT;


		DATA BaseFmap_&category._&service._SOF_&SOF.;
			SET TempRed(KEEP=/* Scheme */ category service MOP Weights Predicted residual)
				Tempprojected(KEEP=/* Scheme */ category service MOP Weights Predicted residual);
			SOF=&SOF;

			IF MOP >= &FirstDateOfProjectedData THEN DO; 
				Weights=.;
				Residual=.;
			END;
			zero=0;
			UpperY = min(max(Weights, Predicted) + 0.03, 1);
			LowerY = max(min(Weights, Predicted) - 0.03, 0);
		RUN;

	    %DropTable(TforecastBfmap);

		/*The placeholder W zeroes are replaced with the results from the regression model*/
		PROC SQL NOPRINT;
			CREATE TABLE TforecastBfmap AS
			SELECT a.*, COALESCE(b.Predicted,0) AS W&SOF
			FROM forecastBfmap(DROP=W&SOF) AS a
			LEFT JOIN BaseFmap_&category._&service._SOF_&SOF. AS b
			  ON a.MOP = b.MOP
			ORDER BY a.MOP;
		QUIT;

		DATA forecastBfmap;
			SET TforecastBfmap;
		RUN;

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   END of MakeAutoModel2;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;


%MEND;


/*
%MethodRegistration(&pFMAP, MakeAutoModel2);
*/
