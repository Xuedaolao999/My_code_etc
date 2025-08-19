/*
~ METHOD_NAME                      - ManualWeights
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - String 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - ManualWeights
~ METHOD_DESCRIPTION               - Externel Manual Weights update
~ PARAMETER_NAME                   - Category Service
~ PARAMETER_VALUE                  - NULL NULL
~ PROGRAMMER                       - Shidong Zhang 
~ DATE_CREATED                     - 2008/03/26
*/
%MACRO ManualWeights(Category, Service);

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   BEGIN ManualWeights;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;


	%LOCAL dsidm nmobs k ThisW1 ThisW2 ThisW3 ThisW4 ThisW5 ThisW6 ThisW7 ThisW8 ThisW9 ThisW10 ThisW11;

	%LET dsidm=%SYSFUNC(OPEN(FMAP.Spcial12881277(WHERE=(MEG="&category" AND FSVC="&service"))));

	%LET nmobs=%SYSFUNC(ATTRN(&dsidm, NLOBSF));
	%PUT NOTE:(SD) The Total Abservations is: &nmobs;

	%IF &nmobs EQ 1 %THEN %DO;
		%DO %WHILE(%SYSFUNC(FETCH(&dsidm)) EQ 0);
			%DO k=1 %TO 11;
				%LET ThisW&k=%SYSFUNC(GETVARN(&dsidm, %SYSFUNC(VARNUM(&dsidm, SOF&k))));
				%PUT NOTE:(SD) Weights of SOF&k is &&ThisW&k;
			%END;

			DATA ForecastBFmap;
				SET ForecastBFmap;
			
				%DO i=1 %TO 11;
					TW&i=&&ThisW&i;
				%END;
			RUN;

		%END;
	
	%END;
		
	%LET RC=%SYSFUNC(CLOSE(&dsidm));

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   END ManualWeights;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

%MEND;
/*
%MethodRegistration(&pFMAP, ManualWeights);
*/
