/*
~ METHOD_NAME                      - CalcualteFmapWeights
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - NA 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - CalcualteFmapWeights
~ METHOD_DESCRIPTION               - CalcualteFmapWeights
~ PARAMETER_NAME                   - 
~ PARAMETER_VALUE                  - 
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/

%MACRO CalcualteFmapWeights(category, Service, LastDate, ForecastStart);

	%LOCAL dsid1 dsid2 dsid;


* List all current macro assignments in log for step-by-step review;
options symbolgen;



	OPTIONS ORIENTATION=LANDSCAPE;
	GOPTIONS CBACK=LightBLUE;
	
	%LET Cutoff=%SYSFUNC(min(&Cutoff, &ForecastStart));
	/*%IF &CUTOFF= %THEN %LET cutOff="01JAN2016"d;*/ * HardCoding Here!!!!!!!!!!!!!!!!!!!!!!!!!!!!!&FirstDateOfAcutalData;
	%LET Nperiod=%SYSFUNC(INTCK(MONTH, &FirstDateOfAcutalData, &LastDateofProjectedData));
	%LET Nreal=%SYSFUNC(INTCK(MONTH, &FirstDateOfAcutalData, &LastDateofAcutalData));

	%IF &service = 336 %THEN %LET Nreal=%EVAL(%SYSFUNC(INTCK(MONTH, &cutoff, &LastDateofAcutalData))-2);
    * The Svc 336 change also exists in MakeAutoModel2;


%PUT NOTE:(SD) *************************************;
%PUT NOTE:(SD) *************************************;
%put &LastDateofAcutalData;
%PUT NOTE:(SD) *************************************;
%PUT NOTE:(SD) *************************************;



	Proc SQL NOPRINT;
		CREATE TABLE DistinctSoF_&category._&service. as
		SELECT DISTINCT SOF 
		FROM FMAP.BaseFmapWeights(WHERE=(category="&category" AND service="&Service" ));
				
			alter table DistinctSoF_&category._&service.
			add AfrsSof char(2)			
			add AfrsSofName char(255);
			
			update DistinctSoF_&category._&service. a
			set AfrsSof = (select AfrsSof
			               from maindm.Dim_afrs_sof
			               where a.sof=Afrs_Sof_ID
                          );				
			
			update DistinctSoF_&category._&service. a
			set AfrsSofName = (select AfrsSofName
			from maindm.Dim_afrs_sof
			where a.sof=Afrs_Sof_ID);
				
		SELECT count(*) INTO: NSOF
		FROM DistinctSoF_&category._&service.;
	Quit;
	
	data DistinctSoF_&category._&service.;
		set DistinctSoF_&category._&service.;
		AfrsSofname=compress(AfrsSofname,"~");
	run;

	%PUT NOTE:(SD) There are &Nsof different sources of fund;

		Data FMAP.ForecastBaseFmapweights; 
          Set FMAP.ForecastBaseFmapweights;
		  if category ~= "&category" or service ~= "&service";
		Run;

		Data FMAP.BaseFmapFact;	
            Set FMAP.BaseFmapFact;
			if ForecastVersionID ~= "A&pDataCycle" OR
			Category ~= "&category" OR
			Service ~= "&service";
		Run;
		
	%IF %SYSFUNC(EXIST(forecastBfmap)) %THEN %DropTable(forecastBfmap);
		Data ForecastBfmap;
			DO i=0 TO &Nperiod;
				category="&category";
				Service="&service";
				MOP=INTNX('Month', &FirstDateOfAcutalData, i);

				%DO j=1 %TO 11;
					W&j=0;
				%END;

				OUTPUT;
			END;
			DROP i;
			FORMAT MOP date7.;
		Run;	

/*Create file check*/
/*Apparently the table is built to hold with all zeros until populated*/
Data ForecastBFmap_1; 
  Set ForecastBFmap; 
Run;



/*******************************************************************************/
/*** BEGIN: If Number of SOFs EQ 1 ****************************************************/
%IF &Nsof = 1 %THEN %DO;
		
		%LET dsid1=%SYSFUNC(OPEN(DistinctSoF_&category._&service., IS));
			%PUT NOTE:(SD) This dsid1: &dsid1;
		%IF %SYSFUNC(FETCH(&dsid1)) = 0 %THEN %DO;
			%LET ThisSOF=%SYSFUNC(GETVARN(&dsid1, %SYSFUNC(VARNUM(&dsid1, SOF))));
			%PUT NOTE:(SD) This SOF is: &ThisSOF;
		%END;
		%ELSE %DO; %PUT ERROR:(SD) distinctSOF has no observations; %END;
	

%PUT NOTE:(SD) ++++++++++++++++++++++++++++++++ &dsid1;
	%LET RC=%SYSFUNC(CLOSE(&dsid1));
%PUT NOTE:(SD) ++++++++++++++++++++++++++++++++ &RC -- &dsid1;


		Data ForecastBfmap;  
            Set ForecastBfmap;
			W&ThisSOF=1;
		Run;

/*Create file check*/
Data ForecastBFmap_2; 
 Set ForecastBFmap; 
Run;

		Proc SQL NOPRINT;
			CREATE TABLE CalculatedBaseFmap as
			SELECT MDY(a.MOP-100*INT(a.MOP/100), 1, INT(a.MOP/100)) AS MOP1,
					a.FMAP1, a.FMAP2, a.FMAP3, a.FMAP4, a.FMAP5, 
					a.FMAP6, a.FMAP7, a.FMAP8, a.FMAP9, a.FMAP10, a.FMAP11,		/*fmap10 and 11 added Aug2015: stcp*/
					b.*, a.FMAP&ThisSOF*b.W&ThisSOF as BaseFmap
	    FROM Fmap.Fmap_MOP as a		
		left JOIN ForecastBfmap as b
		  ON MDY(a.MOP-100*INT(a.MOP/100), 1, INT(a.MOP/100)) = b.MOP
		ORDER BY a.MOP;
		Quit;

		Proc SQL NOPRINT;
			INSERT INTO FMAP.BaseFmapFact( ForecastVersionID, Category, Service, PaymentMonth, BaseFmapValue, TimeStamp) /* i am here */
			(SELECT "A&pDataCycle" AS ForecastVersionID, Category, Service, MOP, BaseFmap, DATETIME()
			FROM CalculatedBaseFmap(WHERE=(&FirstDateOfAcutalData <= MOP <= &LastDateofProjectedData)));
		Quit;
		
	options nonotes;
			Data allmop;
				DO i=0 TO &Nperiod;
						*Scheme="&scheme";
						category="&category";
						Service="&service";
						MOP=INTNX('Month', &FirstDateOfAcutalData, i);
						Weights=1;
						Predicted=1;
						Residual=0;		
						SOF=&ThisSof;					
						OUTPUT;
					END;
					DROP i;
					FORMAT MOP MONYY7.;
				Run;	
	Proc Sort data=allmop; by mop; Run;
	options notes;


	
	Quit;		
		
		DATA BaseFmap_&category._&service._SOF_&ThisSOF.;
			SET allmop;
			
			IF MOP >= &FirstDateOfProjectedData THEN DO; 
				Weights=.;
				Residual=.;
			END;
			zero=0;
			UpperY = min(max(Weights, Predicted) + 0.03, 1);
			LowerY = max(min(Weights, Predicted) - 0.03, 0);
		RUN;
		

%END;
/*** END: If Number of SOFs = 1 *****************************************************/
/*******************************************************************************/



/*******************************************************************************/
/*** BEGIN: If Number of SOFs GE 2 ***************************************************/
	%ELSE %IF &Nsof GE 2 %THEN %DO;
	
		%LET dsid2=%SYSFUNC(OPEN(DistinctSoF_&category._&service., IS));
		%PUT NOTE:(SD) This dsid2: &dsid2;

        %DO %WHILE(%SYSFUNC(FETCH(&dsid2)) = 0);
		  %LET ThisSOF=%SYSFUNC(GETVARN(&dsid2, %SYSFUNC(VARNUM(&dsid2, SOF))));


          options nonotes;
		  Data allrealmop;
			DO i=0 TO %EVAL(&Nreal-1);
					category="&category";
					Service="&service";
					SOF=&ThisSoF;
					MOP=INTNX('Month', &FirstDateOfAcutalData, i);
					OUTPUT;
				END;
				DROP i;
				FORMAT MOP MONYY7.;
		   Run;	
          options notes;


	   %PUT NOTE:(SD)  &Nreal equals what;

       /*cutoff*/
	   Proc SQL NOPRINT;
			 CREATE Table zTempAll as
			 SELECT a.category, a.Service, a.SOF, a.MOP, COALESCE(b.weights, 0) as weights
		     FROM allrealMop as a
			 LEFT JOIN FMAP.BaseFmapWeights(WHERE=(category="&category" and 
					service="&Service" and 
					&cutoff <= MOP < &LastDateOfAcutalData and SOF=&ThisSOF)) as b
			  on a.MOP = b.MOP;
	   Quit;

     Proc Sort Data=zTempAll; 
      by MOP; 
     Run;

     /*Table used to set outlier bounds*/
	 Data zTemp(KEEP=category service MOP SOF Diffs);	
      Set zTempAll;
	  Diffs=DIF(weights);
	   if Diffs ~= .;
	 Run;

    /*Data check on file to be joined below*/
    Data BaseFmapWeights; 
      Set fmap.BaseFmapWeights;	
	  if category = "&category" and service = "&service";
    Run;

	Proc SQL noprint;
		CREATE table TempWeightsCS as
		SELECT Category, Service, SOF, MOP, COALESCE(Weights, 0) as Weights
	    FROM FMAP.BaseFmapWeights(WHERE=(category="&category" and 
				                         service="&Service" and 
				                         &FirstDateOfAcutalData <= MOP <= &LastDateofAcutalData and SOF=&ThisSOF)
                                  );
	Quit;

    Proc Sort data=TempWeightsCS; 
      by MOP; 
    Run;

   options nonotes;
   Data allmop;
	 DO i=0 TO &Nperiod;
		category="&category";
	    Service="&service";
		SOF=&ThisSof;
		MOP=INTNX('Month', &FirstDateOfAcutalData, i);
		Weights=0;
		OUTPUT;
     END;
	 DROP i;
	 FORMAT MOP MONYY7.;
   	Run;	

   Proc Sort data=allmop; 
     by mop; 
   Run;
   options notes;


  Proc SQL NOPRINT;
    CREATE table ForecastBaseFmapWeightsCS as
    SELECT  a.category, a.Service, a.SOF, a.MOP, COALESCE(b.Weights, 0) as Weights
    FROM allMop as a
    left JOIN TempWeightsCS as b
	  on a.MOP = b.MOP;
   Quit;
	
	/*data ForecastBaseFmapWeightsCS;
		set ForecastBaseFmapWeightsCS(where=(mop >= &cutoff));
	run;*/


	%MakeAutoModel2(&category, &service, &ThisSOF, &cutoff, &LastDate);
   /* ZXG:
      Create table work.TforecastBfmap which contain the weights and the predicted weights from PROC REG Procedure, and are 
	  finally appended to the table work.forecastBfmap
	*/
   %END; /* end for the do while */


   %LET RC=%SYSFUNC(CLOSE(&dsid2));

/*TW means ThisWeight*/
/*Create a table filled with ratio allocations*/
Data ForecastBFmap;   
  Set ForecastBFmap;
  Wsum=SUM(W1, W2, W3, W4, W5, W6, W7, W8, W9, W10, W11);  
  %DO i=1 %TO 11; /*update iterations to include the 2 new SOFs, 10 and 11, Aug2015, stcp*/
	TW&i=W&i/Wsum;
   	IF TW&i<0 THEN TW&i=0;
	ELSE IF TW&i >1 THEN TW&i=1;  
  %END;
Run;


/*Create file check*/
Data ForecastBFmap_3; Set ForecastBFmap; Run;


%ManualWeights(&Category, &Service);


%PUT NOTE:(SDZ) pDataCycle=|&pDataCycle| category=|&category| service=|&service| SOF=|&ThisSOF|;



/*************************************************************************/
/*** BEGIN: Individual Patch Fixes ***********************************************/
		%IF &pDataCycle = 1109 %THEN %DO;
			%IF &category ~= 1861 AND &service = 336 %THEN %DO;
				Data ForecastBFmap;		
                  Set ForecastBFmap;
				  IF MOP >= '01JAN09'd THEN DO;
				   TW1=1;
				   TW5=0;
				   END;
				Run;
				%PUT NOTE:(SD) Special Funding ReAllocation for Svc336 other than Category 1861;
			%END;

			%IF &category = 1861 AND &service = 336 %THEN %DO;
				Data ForecastBFmap;		
                   Set ForecastBFmap;
				   IF MOP >= '01JAN09'd THEN DO;
					TW4=1;
					TW5=0;
				   END;
				Run;
				%PUT NOTE:(SD) Special Funding ReAllocation for 1861-336;
			%END;

			%IF (&category = 1261 OR &category = 1262) AND &service = 775 %THEN %DO;
				Data ForecastBFmap;		Set ForecastBFmap;
						IF MOP >= '01JAN09'd THEN DO;
							TW6=1;
							TW9=0;
						END;
				Run;
				%PUT NOTE:(SD) Special Funding ReAllocation for Megs 1261 or 1262 - Svc775;
			%END;

			%IF &category = 1350 AND &service = 791 %THEN %DO;
				Data ForecastBFmap;		Set ForecastBFmap;
						IF MOP >= '01JAN09'd THEN DO;
							TW1=0.7251;
							TW5=1-0.7251;
						END;
				Run;

				%PUT NOTE:(SD) Special Funding ReAllocation for 1350-791;

			%END;
		%END;
		
		/*%IF &FCycle=Oct2017 %THEN %DO;
			%IF &category ~= 1960 AND &service = 101 %THEN %DO;
				Data ForecastBFmap;		Set ForecastBFmap;
						IF MOP >= '01JAN09'd THEN DO;
							TW1=1;
							TW5=0;
						END;
				Run;
				%PUT NOTE:(SD) Fix for no data;
			%END;
		%END;*/			
/*** END: Individual Patch Fixes *************************************************/



 Proc SQL noprint;
		CREATE TABLE CalculatedBaseFmap as
		SELECT MDY(a.MOP-100*INT(a.MOP/100), 1, INT(a.MOP/100)) AS MOP1,
					a.FMAP1, a.FMAP2, a.FMAP3, a.FMAP4, a.FMAP5, a.FMAP6, a.FMAP7, a.FMAP8, a.FMAP9, a.FMAP10, a.FMAP11,
					b.*, SUM(a.FMAP1*b.TW1, a.FMAP2*b.TW2, a.FMAP3*b.TW3, a.FMAP4*b.TW4, 
					a.FMAP5*b.TW5, a.FMAP6*b.TW6, a.FMAP7*b.TW7, a.FMAP8*b.TW8, a.FMAP9*b.TW9,
					a.FMAP10*b.TW10, a.FMAP11*b.TW11) /*zxg*/ 
					AS BaseFmap1
        FROM Fmap.Fmap_MOP as a
		LEFT JOIN ForecastBfmap as b
		  ON MDY(a.MOP-100*INT(a.MOP/100), 1, INT(a.MOP/100)) = b.MOP
        ORDER BY a.MOP;
 Quit;

/*UPDATE BASE FMAP FOR 1230-221 TO SHIFT FMAP CHANGE FROM JAN TO FEB*/
%if (&category=1221 and &service=336) or 
	(&category=1221 and &service=350) or 
	(&category=1221 and &service=610) or
	(&category=1221 and &service=630) 
%then %do;
	data CalculatedBaseFmap;
		set CalculatedBaseFmap;
			if mop = '01JAN17'd then FMAP10=1;
			if mop = '01FEB17'd then FMAP10=0.95;
			if mop = '01JAN18'd then FMAP10=0.95;
			if mop = '01FEB18'd then FMAP10=0.94;
			if mop = '01JAN19'd then FMAP10=0.94;
			if mop = '01FEB19'd then FMAP10=0.93;
	run;
%end;
/*END SPECIAL ACA PATCH*/

/*Original code*/
		Data CalculatedBaseFmap;  	
            Set CalculatedBaseFmap;
			BaseFmap=ROUND(BaseFmap1, 0.000001);
		Run;


Proc SQL NOPRINT;
		INSERT INTO FMAP.BaseFmapFact( ForecastVersionID, Category, Service, PaymentMonth, BaseFmapValue, TimeStamp) /*i am here again*/
		(SELECT "A&pDataCycle" AS ForecastVersionID, Category, Service, MOP, BaseFmap, DATETIME()
FROM CalculatedBaseFmap(WHERE=(&FirstDateOfAcutalData <= MOP <= &LastDateofProjectedData)));
Quit;


%END;
/*** END: If Number of SOFs GE 2 ***********************************************/
/*************************************************************************/


/*UPDATE BASE FMAP FOR 1230-221 TO SHIFT FMAP CHANGE FROM JAN TO FEB*/
%if (&category=1221 and &service=336) or 
	(&category=1221 and &service=350) or 
	(&category=1221 and &service=610) or
	(&category=1221 and &service=630) 
%then %do;
	data FMAP.BaseFmapFact;
		set FMAP.BaseFmapFact;
		LagValue = Lag(BaseFmapValue);
			if PaymentMonth = '01JAN17'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01FEB17'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01JAN18'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01FEB18'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01JAN19'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01FEB19'd then BaseFmapValue = LagValue;
		drop LagValue;	
	run;
%end;

/*fix problem with declining too much in Dec*/
%if (&category=1222 and &service=310) or
	(&category=1222 and &service=333) or
	(&category=1221 and &service=333)
%then %do;
	data FMAP.BaseFmapFact;
		set FMAP.BaseFmapFact;
		LagValue = Lag(BaseFmapValue);
			if PaymentMonth = '01DEC16'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01DEC17'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01DEC18'd then BaseFmapValue = LagValue;
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
	data FMAP.BaseFmapFact;
		set FMAP.BaseFmapFact;
		LagValue = Lag(BaseFmapValue);
			if PaymentMonth = '01NOV16'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01DEC16'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01NOV17'd then BaseFmapValue = LagValue;			
			if PaymentMonth = '01DEC17'd then BaseFmapValue = LagValue;
			if PaymentMonth = '01NOV18'd then BaseFmapValue = LagValue;				
			if PaymentMonth = '01DEC18'd then BaseFmapValue = LagValue;
		drop LagValue;	
	run;
%end;

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   END of CalcualteFmapWeights;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

%MEND;

