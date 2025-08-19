
/*
~ METHOD_NAME                      - ExecuteMethod
~ vCLASS_ID                        - 1 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - NA 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - ExecuteMethod
~ METHOD_DESCRIPTION               - Execute this method 
~ PARAMETER_NAME                   - ThisMethod
~ PARAMETER_VALUE                  - NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/
%MACRO ExecuteMethod(ThisMethod);
    
	%LOCAL dsid0 dsid1 dsid2 RC0 RC1 RC2 MethodName VClassName ThisMethodID
			vClass_ID ThisExecCall thisParameterValues countVar ThisVarName
			ThisVarValue N;
	
	%LET MethodName=%SCAN(&ThisMethod, 1, %STR(.));
	%LET VClassName=%SCAN(&ThisMethod, 2, %STR(.));
	%PUT NOTE:(SD) The Method is &MethodName The vClass is &vClassName;

	%LET dsid0=%SYSFUNC(OPEN(Kernel.vClass(WHERE=(UPCASE(vClass_Name) EQ "%UPCASE(&VClassName)")), IS));
	%IF %SYSFUNC(FETCH(&dsid0)) EQ 0 %THEN %DO;
	    %LET vClass_ID= %SYSFUNC(GETVARN(&dsid0, %SYSFUNC(VARNUM(&dsid0, vClass_ID))));
		%PUT NOTE:(SD) This vClass ID is: &vClass_ID;

		%PUT NOTE:(SD) This Method Name is: %UPCASE(&MethodName);

		%LET dsid1=%SYSFUNC(OPEN(Kernel.Methods(WHERE=(UPCASE(TRIM(Method_Name)) EQ "%UPCASE(&MethodName)" AND vClass_ID EQ &vClass_ID)), IS));
		%IF %SYSFUNC(FETCH(&dsid1)) EQ 0 %THEN %DO;
				%LET ThisMethodID=%SYSFUNC(GETVARN(&dsid1, %SYSFUNC(VARNUM(&dsid1, METHOD_ID))));
				%LET ThisExecCall=%SYSFUNC(GETVARN(&dsid1, %SYSFUNC(VARNUM(&dsid1, EXEC_CALL))));
				
				
				%LET thisParameterValues=;
				%LET countVar=0;
			
				%LET dsid2=%SYSFUNC(OPEN(Kernel.MethodVariables(WHERE=(Method_ID EQ &ThisMethodID)), IS));
				%DO %WHILE (%SYSFUNC(FETCH(&dsid2)) EQ 0);
					%LET countVar=%EVAL(&countVar+1);
					%LET ThisVarName=%QTRIM(%QSYSFUNC(GETVARC(&dsid2, %SYSFUNC(VARNUM(&dsid2, MethodVar_Name)))));
					%LET ThisVarValue=%QTRIM(%QSYSFUNC(GETVARC(&dsid2, %SYSFUNC(VARNUM(&dsid2, MethodVar_Value)))));
					%IF &&PassParameter&countVar NE NULL %THEN %DO;
						%LET ThisVarValue=&&PassParameter&countVar;
						%LET PassParameter&countVar=NULL;
					%END;
					%LET thisParameterValues=%STR(&thisParameterValues., &ThisVarName = &ThisVarValue);

				%END;

				%LET RC2=%SYSFUNC(CLOSE(&dsid2));

				%IF &thisParameterValues NE %THEN %DO;
					%LET N=%SYSFUNC(LENGTH(&thisParameterValues)); 
					%PUT NOTE:(SD) N=&N;

					%LET thisParameterValues=%SUBSTR(&thisParameterValues, 2, %EVAL(&N-1));
					%PUT NOTE:(SD) The parameters are |&thisParameterValues|;

					%IF &ThisExecCall EQ 1 %THEN %do;
					    %let x = &MethodName._&ThisMethodID.(&thisParameterValues.);
						%put x 1 is +++++++++++++++++++++++&x++++++++++++++++++++++++++++++;
						%return;
						%end;
					%ELSE %do;
						%let x = &MethodName.(&thisParameterValues.);
						%put x 2 is +++++++++++++++++++++++&x++++++++++++++++++++++++++++++;
						%end;
				%END;
				%ELSE %DO;
					%IF &ThisExecCall EQ 1 %THEN %do;
						%let x = &MethodName._&ThisMethodID;
						%put x 3 is +++++++++++++++++++++++&x++++++++++++++++++++++++++++++;
						%end;
					%ELSE %do;
						%let x = &MethodName;
						%put x 4 is +++++++++++++++++++++++&x++++++++++++++++++++++++++++++;
						%end;
				%END;
			
		%END;
		%ELSE %PUT ERROR:(SD) The Method Name is NOT correct;

		%LET RC1=%SYSFUNC(CLOSE(&dsid1));
	%END;	 
	%ELSE %PUT ERROR:(SD) The Class Name is NOT correct;

	%LET RC0=%SYSFUNC(CLOSE(&dsid0));
%MEND;
%*%ExecuteMethod(GenerateNewMexp2.GeneralParameters);

%*%ExecuteMethod(CreateCycleViews.DataMgmt);
%*%ExecuteMethod(PopulateForecastCells.Methods);
%*%ExecuteMethod(UpdateForImports.Methods);
%*%ExecuteMethod(MakeLibrary.DirLiBDB) ;
%*%ExecuteMethod(AssignPointers.DirLiBDB); 
%ExecuteMethod(MakeLibrary.DirLiBDB)
