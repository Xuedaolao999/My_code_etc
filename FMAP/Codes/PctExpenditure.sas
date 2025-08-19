/*
~ METHOD_NAME                      - PctExpenditure
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - String 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - PctExpenditure
~ METHOD_DESCRIPTION               - Percentage of expenditure
~ PARAMETER_NAME                   - ThisCycle
~ PARAMETER_VALUE                  - &pDataCycle 
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/

%MACRO PctExpenditure(ThisCycle);

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   BEGIN PctExpenditure;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;


%LOCAL ThisYrMon YrMonThisCycle;
%LET ThisYrMon=%CycleToYrMonth(&ThisCycle);
%PUT NOTE: (SD) ThisYrMon is: &ThisYrMon;

%IF %SYSFUNC(MONTH(&ThisYrMon)) LT 10 %THEN %LET YrMonThisCycle=%SYSFUNC(YEAR(&ThisYrMon))0%SYSFUNC(MONTH(&ThisYrMon));
%ELSE %LET YrMonThisCycle=%SYSFUNC(YEAR(&ThisYrMon))%SYSFUNC(MONTH(&ThisYrMon));

%PUT NOTE:(SD) YrMonThisCycle=&YrMonThisCycle;

%*UniqueCombination;

DATA Fmap.ForecastExpenditureLags;
	SET Lagfctr.Loadlag_F;
RUN;

PROC SQL NOPRINT;
	CREATE TABLE FMAP.AllExpLags AS
	SELECT a.category AS ExpenditureCategoryMcFfs,
			a.service AS BoAfrsService,
			b.ServiceMonth,
			b.AfrsExpenditureLagFactor AS ExpenditureLagFactor,
			"&ThisCycle" AS BienniumMonthID
			/*"&ThisScheme" AS Scheme */
	FROM Fmap.ForecastPTModelsCurrent AS a
	LEFT JOIN Fmap.ForecastExpenditureLags AS b
	ON a.service EQ b.BoAfrsService
	ORDER BY a.category, a.service, b.ServiceMonth;
QUIT;


	PROC SORT DATA=FMAP.AllExpLags(WHERE=(BienniumMonthID="&ThisCycle" /*AND Scheme="&ThisScheme"*/))
			OUT=ExpenditureLagFact&ThisCycle;
	BY ExpenditureCategoryMcFfs BoAfrsService DESCENDING ServiceMonth;
	RUN;

	DATA ExpenditureLagFact&ThisCycle;
		SET ExpenditureLagFact&ThisCycle;

		CatSer=ExpenditureCategoryMcFfs||BoAfrsService;
		AcumPct=1/ExpenditureLagFactor;
		
	RUN;

	PROC SORT DATA=ExpenditureLagFact&ThisCycle;
		BY catser DESCENDING ServiceMonth;
	RUN;

	DATA FMAP.ExpenditureLagFact&ThisCycle(KEEP=BienniumMonthID /* Scheme */ 
				ExpenditureCategoryMcFfs BoAfrsService LagOrder pct);
		SET ExpenditureLagFact&ThisCycle;
		By CatSer;
		RETAIN PriorPct;
		IF first.CatSer THEN pct=Acumpct;
		ELSE pct=Acumpct-PriorPct;

		PriorPct=Acumpct;
		FORMAT AcumPct pct PriorPct PERCENT19.2;
		NLagOrder=(INT(&YrMonThisCycle/100)-INT(ServiceMonth/100))*12 +
				&YrMonThisCycle-100*INT(&YrMonThisCycle/100)-
				ServiceMonth+100*INT(ServiceMonth/100);
		LagOrder="Lag"||PUT(NlagOrder, $2.);	
	RUN;

	PROC SORT DATA=FMAP.ExpenditureLagFact&ThisCycle;
		BY BienniumMonthID /* Scheme */ ExpenditureCategoryMcFfs BoAfrsService LagOrder pct;
	RUN;

	PROC TRANSPOSE DATA=FMAP.ExpenditureLagFact&ThisCycle OUT=FMAP.PctExpenditure(DROP=_NAME_);
		BY BienniumMonthID /* Scheme */ ExpenditureCategoryMcFfs BoAfrsService;
		ID LagOrder;
		VAR Pct;
	RUN;

	%PUT ;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT NOTE:(SD)                   END of PctExpenditure;
	%PUT NOTE:(SD)*************************************************************************;
	%PUT ;

%MEND;


