
/*
~ METHOD_NAME                      - MethodRegistration
~ vCLASS_ID                        - 1 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - File 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - MethodRegistration
~ METHOD_DESCRIPTION               - Regist a method
~ PARAMETER_NAME                   - ThisDir ThisMethod
~ PARAMETER_VALUE                  - &ThisDir &ThisMethod
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/
%MACRO MethodRegistration(ThisDir, ThisMethod);

	%LOCAL deleteMethod dsid RC Nvar Nvalue countVar;
   %* %put NOTE: >>>>>>>>>>>>>>>>>+++++"&ThisDir.&ThisMethod..sas";
	
	DATA temp;
		LENGTH ThisParameter PriorParameter $100 ThisParameterValue PriorParameterValue $260;
		INFILE "&ThisDir.&ThisMethod..sas" PAD lrecl=1000;
		INPUT FirstChar $1 @;
		RETAIN PriorParameter PriorParameterValue;

		IF FirstChar = '~' THEN DO;
			INPUT ThisLine $ 2-1000;
	
				ThisParameter=TRIM(SCAN(ThisLine, 1, "~-"));
				ThisParameterValue=TRIM(SCAN(ThisLine, 2, "~-"));

				IF ThisParameter='+' THEN DO;
					ThisParameter=PriorParameter;
					ThisParameterValue=TRIM(PriorParameterValue)||TRIM(' ')||TRIM(ThisParameterValue);
				END;

				CALL SYMPUT(TRIM(LEFT(ThisParameter)), TRIM(LEFT(ThisParameterValue)));

				PriorParameter=ThisParameter;
				PriorParameterValue=ThisParameterValue;
		END;

	RUN;
   
	%LET deleteMethod=0;

	%LET dsid=%SYSFUNC(OPEN(Kernel.Methods(WHERE=(UPCASE(TRIM(LEFT(METHOD_NAME)))="%UPCASE(&METHOD_NAME)" AND vCLASS_ID=&vCLASS_ID)), IS));
		
	%IF %SYSFUNC(FETCH(&dsid)) EQ 0 %THEN %DO;
		%LET MethodID=%SYSFUNC(GETVARN(&dsid, %SYSFUNC(VARNUM(&dsid, METHOD_ID))));
		%PUT NOTE:(SD) This Method ID is: &MethodID;
		%PUT NOTE:(SD) This Method Name is: |&METHOD_NAME|;
		%PUT NOTE:(SD) This vClass_ID is: |&vCLASS_ID|;
		%LET deleteMethod=1;

		PROC SQL NOPRINT;
			DELETE FROM Kernel.MethodVariables
			WHERE Method_ID=&MethodID;
		QUIT;
	%END;
	
	%LET RC=%SYSFUNC(CLOSE(&dsid));

	%IF &deleteMethod EQ 1 %THEN %DO;
		PROC SQL NOPRINT;
			DELETE FROM Kernel.Methods
			WHERE UPCASE(TRIM(LEFT(METHOD_NAME)))="%UPCASE(&METHOD_NAME)" AND vCLASS_ID=&vCLASS_ID;
		QUIT;

		%LET deleteMethod=0;
	%END;

	%GetSequence(Methods);
	%LET ThisMethodID=&ThisSequenceValue;

	PROC SQL NOPRINT;
		INSERT INTO Kernel.Methods(METHOD_ID, METHOD_NAME, vCLASS_ID, EXEC_CALL, INPUT_IMPLEMENTATION_FORM,
				METHOD_RETURN_VALUE, RETURN_IMPLEMENTATION_FORM, METHOD_LABEL,
				METHOD_DESCRIPTION, PROGRAMMER, DATE_CREATED)
		VALUES( &ThisSequenceValue, "&METHOD_NAME", &vCLASS_ID, &EXEC_CALL, "&INPUT_IMPLEMENTATION_FORM",
				"&METHOD_RETURN_VALUE", "&RETURN_IMPLEMENTATION_FORM", "&METHOD_LABEL",
				"&METHOD_DESCRIPTION", "&PROGRAMMER", "&DATE_CREATED");
	QUIT;

	%LET Parameter_Value=%SUPERQ(Parameter_Value);

	%PUT NOTE:(SD)Parameter_Name is: &Parameter_Name;
	%PUT NOTE:(SD)Parameter_Value is: &Parameter_Value;

	%LET Nvar=%countWords(&Parameter_Name);
	%LET Nvalue=%countWords(&Parameter_Value);

	%IF %EVAL(&Nvar EQ &Nvalue) %THEN %DO;
		%*IF &Nvar NE 0 %THEN %DO;
			%LET countVar=1;

			%DO %WHILE(%QSCAN(&Parameter_Name, &countVar, %STR( )) NE );
				%LET ThisMethodVar_&countVar=%QSCAN(&Parameter_Name, &countVar, %STR( ));
				%LET ThisMethodVar_Value_&countVar=%QSCAN(&Parameter_Value, &countVar, %STR( ));

				%GetSequence(MethodVariables);

				PROC SQL NOPRINT;
					INSERT INTO Kernel.MethodVariables(METHODVAR_ID, METHOD_ID, METHODVAR_NAME, METHODVAR_VALUE, DESCRIPTION)
					VALUES( &ThisSequenceValue, &ThisMethodID, "&&ThisMethodVar_&countVar", "&&ThisMethodVar_Value_&countVar", " ");
				QUIT; 

				%LET countVar=%EVAL(&countVar+1);
			%END;
			%IF &EXEC_CALL NE 0 %THEN %DO;
			    %PUT NOTE: >>>>>>>>>>>>>>>>i AM HERE IN THE ABOVE;
                %PUT NOTE: COPY FROM >>>>>>>>>>>>>>>"&pDPrograms.&ThisMethod._&MethodID..sas";
				%PUT NOTE: COPY TO >>>>>>>>>>>>>>>>>>>>>>>>>>>"&pDProgramRecycle.&ThisMethod._&MethodID..sas";
				%RETURN;
				%SYSEXEC(COPY "&pDPrograms.&ThisMethod._&MethodID..sas" "&pDProgramRecycle.&ThisMethod._&MethodID..sas");
				%SYSEXEC(DEL "&pDPrograms.&ThisMethod._&MethodID..sas");
				%*SYSEXEC(COPY "&ThisDir.&ThisMethod..sas" "&pDPrograms.&ThisMethod._&ThisMethodID..sas");

				DATA _NULL_;
					INFILE "&ThisDir.&ThisMethod..sas" PAD lrecl=1000;
					FILE "&pDPrograms.&ThisMethod._&ThisMethodID..sas" PAD lrecl=900;

					INPUT firstChar $1-7 @;

						IF firstChar='%MACRO' THEN DO;
							INPUT ThisLine $8-1000;

							IF INDEX(ThisLine, "(") NE 0 THEN DO;
								ThisFile=SCAN(TRIM(ThisLine), 1, "(");
								ThisParameters=SCAN(TRIM(ThisLine), 2, "()");
								NEWLINE='%MACRO '||TRIM(ThisFile)||"_&ThisMethodID.("||TRIM(ThisParameters)||");";
							END;
							ELSE DO;
								NEWLINE='%MACRO '||SCAN(TRIM(ThisLine), 1, ";")||"_&ThisMethodID.;";
							END;
						END;
						ELSE DO;
							INPUT ThisLine $1-1000;
							NewLine=ThisLine;
						END;

						PUT NewLine;
				RUN;
				
				%INCLUDE "&pDPrograms.&ThisMethod._&ThisMethodID..sas";
			%END;
			%ELSE %DO;
			%PUT NOTE: >>>>>>>>>>>>>>>>i AM HERE IN THE BELOW;
			    %PUT NOTE: COPY FROM >>>>>>>>>>>>>>>"&pDPrograms.&ThisMethod._&MethodID..sas";
				%PUT NOTE: COPY TO >>>>>>>>>>>>>>>>>>>>>>>>>>>"&pDProgramRecycle.&ThisMethod._&MethodID..sas";
				%RETURN; 
				%SYSEXEC(COPY "&pDPrograms.&ThisMethod..sas" "&pDProgramRecycle.&ThisMethod._&MethodID..sas");
				%SYSEXEC(DEL "&pDPrograms.&ThisMethod..sas");
				%SYSEXEC(COPY "&ThisDir.&ThisMethod..sas" "&pDPrograms.&ThisMethod..sas");	
				%IF %UPCASE(&ThisMethod) NE %UPCASE(MethodRegistration) %THEN %DO;
					%INCLUDE "&pDPrograms.&ThisMethod..sas";
				%END;	
			%END;
		%*END;	
		%*ELSE %DO;
			%*IF &EXEC_CALL NE 0 %THEN %DO;
				%*SYSEXEC(COPY "&pDPrograms.&ThisMethod._&MethodID..sas" "&pDProgramRecycle.&ThisMethod._&MethodID..sas");
				%*SYSEXEC(DEL "&pDPrograms.&ThisMethod._&MethodID..sas");
				%*SYSEXEC(COPY "&ThisDir.&ThisMethod..sas" "&pDPrograms.&ThisMethod._&ThisMethodID..sas");

			%*END;
			%*ELSE %DO;
				%*SYSEXEC(COPY "&pDPrograms.&ThisMethod..sas" "&pDProgramRecycle.&ThisMethod._&MethodID..sas");
				%*SYSEXEC(DEL "&pDPrograms.&ThisMethod..sas");
				%*SYSEXEC(COPY "&ThisDir.&ThisMethod..sas" "&pDPrograms.&ThisMethod..sas");		
			%*END;
		%*END;
	%END;
	%ELSE %PUT ERROR:(SD) The Number of parameters of Method &METHOD_NAME are not equal to the Number of default values!;
 
%MEND;

%LET Dir = \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\PrimaryTrend\;
%let ThisMethod = Adult_Kid_Graph;


%MethodRegistration(&Dir, &ThisMethod);
