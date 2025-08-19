/*
~ METHOD_NAME                      - MOP_FMAP
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - NA 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - MOP_FMAP
~ METHOD_DESCRIPTION               - Calcualte Month of payment Fmap 
~ PARAMETER_NAME                   - Test
~ PARAMETER_VALUE                  - NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/

%MACRO MOP_FMAP(Test);

/*%LET cutOff=&FirstDateOfAcutalData;*/
/*%LET cutOff="01JAN2016"d;*/


	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   BEGIN MOP_FMAP;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;


	%LOCAL dsid RC category service;

	*%PrepareBFAMpweights; 
	* Because the database table with SOF is not ready, this part may need changes;

	

	%*LET dsid=%SYSFUNC(OPEN(Etlmd.ForecastMegXsvc, IS));

	%IF %UPCASE(&test) = YES OR %UPCASE(&test) = Y %THEN %LET dsid=%SYSFUNC(OPEN(FMAP.ForecastPTmodelsCurrent(WHERE=(UPCASE(test)='X'))));
	%ELSE %DO;
		PROC SQL NOPRINT;
		CREATE TABLE FMAP.ForecastBaseFmapweights 
		( 	/* Scheme CHAR(1), */
			category CHAR(4),
			service CHAR(3),
			MOP DATE,
			W1 FLOAT,
			W2 FLOAT,
			W3 FLOAT,
			W4 FLOAT,
			W5 FLOAT,
			W6 FLOAT,
			W7 FLOAT,
			W8 FLOAT,
			W9 FLOAT, 
            W10 FLOAT, 
            W11 FLOAT);		/* W10 and W11 added by stcp 8-14-15*/
	QUIT;


	PROC SQL NOPRINT;
		CREATE TABLE forecastBfmap
		( 	/* Scheme CHAR(1), */
			category CHAR(4),
			service CHAR(3),
			MOP DATE,
			W1 FLOAT,
			W2 FLOAT,
			W3 FLOAT,
			W4 FLOAT,
			W5 FLOAT,
			W6 FLOAT,
			W7 FLOAT,
			W8 FLOAT,
			W9 FLOAT, 
            W10 FLOAT, 
            W11 FLOAT);		/* W10 and W11 added by stcp 8-14-15*/
	QUIT;

	PROC SQL NOPRINT;
		CREATE TABLE FMAP.BaseFmapFact
		( ForecastVersionID CHAR(6),
		  Category CHAR(4),
		  Service CHAR(3),
		  PaymentMonth DATE,
		  BaseFmapValue FLOAT,
		  TimeStamp DATE
         );
	QUIT;
	
	DATA FMAP.BaseFmapFact;
		SET FMAP.BaseFmapFact;
		FORMAT TimeStamp DATETIME20.;
	RUN;

		%LET dsid=%SYSFUNC(OPEN(FMAP.ForecastPTmodelsCurrent));
	%END;

	%DO %WHILE (%SYSFUNC(FETCH(&dsid)) = 0);
		%LET category=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, category))));
		%LET service=%SYSFUNC(GETVARC(&dsid, %SYSFUNC(VARNUM(&dsid, service))));
		%LET LastDate=%SYSFUNC(GETVARN(&dsid, %SYSFUNC(VARNUM(&dsid, LastDate))));
		%LET ForecastStart=%SYSFUNC(GETVARN(&dsid, %SYSFUNC(VARNUM(&dsid, ForecastStart))));

	%CalcualteFmapWeights(&category, &Service, &LastDate, &ForecastStart);
	%END;
	
	%LET RC=%SYSFUNC(CLOSE(&dsid));


	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   END MOP_FMAP;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;


%MEND;

/*return to MainFMAP*/	

/*
%MethodRegistration(&pFMAP, MOP_FMAP);
*/

/*
%CalcualteFmapWeights(category=1003, Service=031, cutoff=);
*/
