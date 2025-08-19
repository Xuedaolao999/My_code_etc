dm 'log' clear;

DATA temp;
		LENGTH ThisParameter PriorParameter $100 ThisParameterValue PriorParameterValue $260;
		INFILE "\\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\PrimaryTrend\Adult_Kid_Graph.sas"  PAD lrecl=1000;
		INPUT FirstChar $1  SecondChar $2 @;
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
				%put ThisParameter is +++++++++++++++++++++++++++&ThisParameter;
		END;
		if FirstChar = '*' and SecondChar = '/' then stop;

	RUN;


	%put ThisParameter is +++++++++++++++++++++++++++&EXEC_CALL;
/*	proc print data = temp;	run; */

/*	proc sql; 	  drop table temp;	quit; */


	proc print data = Kernel.methods;
	  *where upcase(METHOD_NAME) = upcase("Adult_Kid_Graph");
	run; 
