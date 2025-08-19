/*
~ METHOD_NAME                      - FmapForecastAverage
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - String 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - FmapForecastAverage
~ METHOD_DESCRIPTION               - FmapForecastAverage
~ PARAMETER_NAME                   - category service FirstDate LastDate
~ PARAMETER_VALUE                  - NULL NULL NULL NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/

%MACRO FmapForecastAverage(category, service, FirstDate, LastDate);

/*Jn changed start date of forecast*/
/*%let PreferredStart = '01Jan2014'd;*/
/*%let ForecastStart = %sysfunc(max(&FirstDate, &PreferredStart));*/

%LOCAL ThisRatioMEAN ThisRatioMEDIAN;

/*DATA FmapRatio&category._&service.Truncate;
	SET FMAP.FmapRatio&category._&service(where=(mos >= &ForecastStart));
RUN;*/

/*proc sql;
	create table FmapRatio&category._&service.Truncate as
	select *
	from FMAP.FmapRatio&category._&service
	where mos >= &ForecastStart;
quit;*/

%Q1Q3IQR(infile=FmapRatio&category._&service.Truncate, var=FmapRatio, category=, service=, AbnormalCriteria=3);
/*%Q1Q3IQR(infile=FMAP.FmapRatio&category._&service, var=FmapRatio, category=, service=, AbnormalCriteria=3);*/

/*JN: replace outlier FmapRatio values with computed upper and lower bounds*/
DATA adjFmapRatio;
	SET FMAP.FmapRatio&category._&service;
	IF FmapRatio > &Ahigher THEN FmapRatio=&Ahigher;
	ELSE IF FmapRatio < &Alower THEN FmapRatio=&Alower;
RUN;

ODS OUTPUT SUMMARY=FmapForecast;
PROC MEANS DATA=adjFmapRatio(WHERE=(&ForecastStart <= MOS <= &LastDate)) MEAN MEDIAN;
	VAR FmapRatio;
RUN;

DATA _NULL_;
	SET FmapForecast;
	CALL SYMPUT('ThisRatioMEAN', FmapRatio_Mean);
	CALL SYMPUT('ThisRatioMEDIAN', FmapRatio_Median);
RUN;

%PUT NOTE:(SD) The FmapRatio Mean for &Category - &Service is: &ThisRatioMEAN;
%PUT NOTE:(SD) The FmapRatio Median for &Category - &Service is: &ThisRatioMEDIAN;

/*HARD CODE OVERRIDES - ProjectedFmapRatio*/
/*####################################################################################################*/
%if &FCycle=Oct2017 and
	(&category=1252 and &service=740)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1251 and &service=310)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1480 and &service=211)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1221 and &service=671)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1262 and &service=310)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1221 and &service=211)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1222 and &service=221)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1222 and &service=375)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1350 and &service=211)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2017 and
	(&category=1230 and &service=310)
%then %let ThisRatioMEAN=1;
/*####################################################################################################*/

DATA FMAP.FmapRatio&category._&service;
	SET FMAP.FmapRatio&category._&service;
	ProjectedFmapRatio=&ThisRatioMean;
	*IF &pDataCycle EQ 1109 AND &category EQ 1920 AND &service EQ 290 THEN Projected=1;
	ProjectedFmap=FmapMOS*ProjectedFmapRatio;

	IF MOS > &LastDateOfAcutalData THEN DO;
		FmapRatio=&ThisRatioMean;
		*IF &pDataCycle EQ 1109 AND &category EQ 1920 AND &service EQ 290 THEN FmapRatio=1;
		FedShareValue=FmapRatio*FmapMOS;
	END;
RUN;
	%SetConversionRatio1(&Category, &Service, AVERAGE);

%MEND;
/*
%MethodRegistration(&pFMAP, FmapForecastAverage);
*/

/* %FmapForecastAverage(ThisCycle=0724, category=1100, service=005, FirstDate='01JUL2003'd); */

