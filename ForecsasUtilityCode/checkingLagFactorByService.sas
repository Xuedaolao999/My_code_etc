/*******************************************************************************
 Before run this code, run the 
 Q:\ForecastOFM\Production\NwCycle1912_02\ForecastPTFmap\WorkingProgs\Initialize_94_PC_02.sas
 to set up the environment 
*******************************************************************************/

dm 'log' clear;

libname Lagfctr "Q:\ForecastOFM\Production\NwCycle1912_02\ForecastPTFmap\Forecast Process Specific Files\Cycle 1912\Version A\LagFactor";


data check;
  set Lagfctr.M_smexp1912;
run; 

libname Lagfctr clear;

proc contents data = check;
run; 

%let service=101;

data check382;
  set check;
/*  where service = '382';*/
where service = "&service";
run; 

proc print data = check382;
run; 

data check382;
  set check382;
  IF SUBSTR(MOP, 4, 1) ^='R';
			IF INPUT(SUBSTR(MOP, 3, 2),2.) <=24;
			RENAME MOP=MOP2;
			MOS1=MDY(mos-int(mos/100)*100, 1, int(mos/100));
			FORMAT MOS1 MONYY7.;
run; 


data check382_1;
  set check382;
  Mon = 6+put(substr(MOP2,3,2), 2.);
	Month = Mon-int(mon/12)*12;
	IF Month=0 THEN Month=12;

	yr=put(substr(MOP2,1,2), 2.);
	IF Mon le 12 THEN year=2000+yr-2;
	ELSE IF Mon gt 12 AND Mon le 24 THEN year=2000+yr-1;
		 ELSE year=2000+yr;
	Nyrmon=mdy(Month, 1, year);
	RENAME Nyrmon=MOP;
	FORMAT Nyrmon Monyy7.;
	DROP Mon Month yr year;
run;



PROC SQL;
 		CREATE TABLE Mexplag0 AS
 		SELECT service, 
				intck('month', mos1, mop) AS PDATE, 
				MOS1 AS MOS format=monyy7., 
				MOP, 
				SUM(PAID) AS Total FORMAT COMMA19.2
 		FROM check382_1
 		GROUP BY service, MOS1, MOP, PDATE
 		ORDER BY service, MOS1 DESC, MOP, PDATE;
	QUIT;


	PROC SORT DATA=Mexplag0;
		BY service mos pdate;
	RUN;

	DATA MEXPlag1;
		SET Mexplag0;
		RETAIN totalpaid;
		BY service mos;
		IF first.mos THEN totalpaid=0;
		totalpaid=totalpaid + total;
	RUN;


	

PROC SORT DATA=MEXPlag1(where=(pdate ^=.));
	BY service MOS PDATE ;
RUN;



PROC TRANSPOSE DATA=MEXPlag1(where=(0 LE PDATE LE 19)) OUT=MEXPlag2;
	BY service MOS;
	ID PDATE;
	VAR TotalPaid;
RUN;



dm 'log' clear;
%let Level = M;
%let TheCycle = Test;
%LET ThisYrMon=%UNQUOTE(%CycleToYrMonth(1912));
%let Lags =18;
%put &ThisYrMon;

%macro transform (LagLength = 19);
DATA Mexplag3;
	SET MEXPlag2;
	DROP _NAME_;
	%DO i=0 %TO &LagLength;
		RENAME _&i=LAG&i;
	%END;	
  RUN;

DATA LAG_TABLE;
	SET Mexplag3;

	%DO i= 1 %TO &LagLength;
		%LET j=%EVAL(&i-1);
		if lag&j NOT in (0, .) AND Lag&i NE . THEN
			LagRatio&j = Lag&i/Lag&j;
		ELSE LagRatio&j=.;
	%END;

	DROP LAG0-LAG&lagLength;
RUN;



%DO i=0 %TO %EVAL(&LagLength-1);
	DATA Lagratio&i;
		SET Lag_table(WHERE=(INTNX('MONTH', &ThisYrMon, %EVAL(-&i-1)) GE MOS GE INTNX('MONTH', &ThisYrMon, %EVAL(-&i-18)) ));
			MOS&i=MOS;
			ID=INTCK('MONTH', MOS, INTNX('MONTH', &ThisYrMon, %EVAL(-&i-1)));
			FORMAT MOS&i MONYY7.;
			KEEP ID SERVICE MOS&i LagRatio&i;
		RUN;
	%IF &i EQ 0 %THEN %DO;
		DATA Work.&Level._Lag_Table&TheCycle;
			SET Lagratio&i;
		RUN;
	%END;
	%ELSE %DO;
		PROC SORT DATA=Work.&Level._Lag_Table&TheCycle;
			BY service id;
		RUN;

		PROC SORT DATA=LagRatio&i;
			BY service id;
		RUN;
		
		PROC SQL NOPRINT;
			CREATE TABLE ZtempLF AS
			SELECT a.*, MOS&i, b.LagRatio&i
			FROM Work.&Level._Lag_Table&TheCycle AS a
			LEFT JOIN LagRatio&i AS b
			ON a.Service EQ b.Service AND a.ID EQ b.ID
			ORDER BY a.Service, a.ID;
		QUIT;

		DATA Work.&Level._Lag_Table&TheCycle ZZ;
			SET ZtempLF;
		RUN;
	%END;

%END;
	DATA Work.&Level._Lag_Table&TheCycle ZZZ;
			SET Work.&Level._Lag_Table&TheCycle;
				IF ABS(LagRatio0) > 50 OR LagRatio0<0 THEN LagRatio0=.;
			%DO i=1 %TO %EVAL(&lagLength-1);
				IF ABS(LagRatio&i) > 20 THEN LagRatio&i=.;
				ELSE IF &i GE 4 AND (ABS(LagRatio&i) > 2 ) THEN LagRatio&i=.;
				ELSE IF &i GE 10 AND ABS(LagRatio&i) > 1.5 THEN LagRatio&i=.;
			%END;
		RUN;


ODS OUTPUT SUMMARY=CILag_Table(DROP=VName_LagRatio1-VName_LagRatio&lagLength);
PROC MEANS DATA=Work.&Level._Lag_Table&TheCycle MEDIAN STD;
	BY SERVICE;
	VAR Lagratio0-Lagratio%EVAL(&lagLength-1);
RUN;


DATA CILag_Table&TheCycle;
	SET CILag_Table;
	%DO i = 0 %TO %EVAL(&lagLength-1);
		LowerLimit_lag&i=LagRatio&i._median-2*LagRatio&i._StdDev;
		upperLimit_lag&i=LagRatio&i._median+2*LagRatio&i._StdDev;
	%END;
RUN;

PROC SQL NOPRINT;
	CREATE TABLE Work.&Level._Mlag_table&TheCycle AS
	SELECT a.Service, %DO i = 0 %TO %EVAL(&lagLength-1); MOS&i,
			CASE
			WHEN a.LagRatio&i EQ . THEN .
			When a.LagRatio&i ne . and (LowerLimit_Lag&i = . or upperLimit_Lag&i= .) then a.LagRatio&i/2  /*zxg */
			WHEN a.LagRatio&i LT b.LowerLimit_Lag&i THEN b.LowerLimit_Lag&i
			WHEN a.LagRatio&i GT b.upperLimit_Lag&i THEN b.upperLimit_Lag&i
			ELSE a.LagRatio&i
			END AS LagRatio&i,
			%END;
			"END" AS END
	FROM Work.&Level._Lag_Table&TheCycle AS a
	LEFT JOIN CILag_Table&TheCycle AS b
	ON a.Service EQ b.Service
	ORDER BY a.service;
QUIT;






ODS OUTPUT SUMMARY=MeidanLag_Table(DROP=VName_LagRatio1-VName_LagRatio&lagLength);
PROC MEANS DATA=Work.&Level._MLag_Table&TheCycle MEDIAN; /*MEDIAN */
	BY SERVICE;
	VAR Lagratio0-Lagratio%EVAL(&lagLength-1);
RUN;

ODS OUTPUT SUMMARY=MeanLag_Table(DROP=VName_LagRatio1-VName_LagRatio&lagLength);
PROC MEANS DATA=Work.&Level._MLag_Table&TheCycle MEAN; /*MEAN */
	BY SERVICE;
	VAR Lagratio0-Lagratio%EVAL(&lagLength-1);
RUN;

ODS OUTPUT SUMMARY=stdLag_Table(DROP=VName_LagRatio1-VName_LagRatio&lagLength);
PROC MEANS DATA=Work.&Level._Lag_Table&TheCycle std;
	BY SERVICE;
	VAR Lagratio0-Lagratio%EVAL(&lagLength-1);
RUN;



DATA Work.&Level._lagfactors&TheCycle;
	SET MeidanLag_table;
			IF  LagRatio&Lags._Median EQ . THEN LagRatio&Lags._Median=1;
			lag&lags=LagRatio&lags._Median;
			*IF lag&lags LT 1 THEN lag&lags=1;
/*			IF service in &defaultOne THEN lag&lags=1;*/

		%DO i=%EVAL(&lags-1) %TO 0 %BY -1;
			%LET k=%EVAL(&i+1);
			IF LagRatio&i._Median EQ . THEN LagRatio&i._Median=1;
			lag&i=lag&k.*LagRatio&i._Median;

			*IF lag&i LT 1 THEN lag&i=1;
			
		%END;
		KEEP service lag0-lag&lagLength;
RUN;



%mend;

%transform;

/* table Lagfctr.&Level._lagfactors&TheCycle is the final table contain the lag ratio 
   in our checking process, it is work.M_lagfactorstest!!
*/
title "this is the lag factor for the servie &service";
proc print data = M_lagfactorstest;
run; 

/*
proc print data = MeidanLag_table;
run; 

proc print data = M_MLag_TableTest;
run; 

data t1;
 set Work.M_MLag_TableTest;
 keep LagRatio4;
run; 

proc means data = t1 median;
run; 

%let dat = LAG_TABLE;
title "&dat";
proc print data= &dat;
run; 

*/
