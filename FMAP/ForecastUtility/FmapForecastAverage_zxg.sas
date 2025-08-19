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
%if &FCycle=Oct2018 and
	(&category=1252 and &service=740)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=1251 and &service=310)
%then %let ThisRatioMEAN=1;

/*ZXG: Modified at 1/3/2018*/
%if &FCycle=Oct2020x and
	(&category=1480 and &service=211)
%then %let ThisRatioMEAN=1; 

%if &FCycle=Oct2018 and
	(&category=1221x and &service=671)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=12622 and &service=310)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=1221 and &service=211)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=1222 and &service=221)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=1222 and &service=375)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=1350 and &service=211)
%then %let ThisRatioMEAN=1;

%if &FCycle=Oct2018 and
	(&category=1230 and &service=310)
%then %let ThisRatioMEAN=1;
/* ZXG ADDED ------------------------- 12/29/2017 ---------------*/
%if &FCycle=Oct2018 and
	(&category=1261 and &service=671)
%then %let ThisRatioMEAN=1.005;
/* ZXG ADDED ------------------------- 1/2/2018 ---------------*/
%if &FCycle=Oct2018 and
	(&category=1211 and &service=671)
%then %let ThisRatioMEAN=1.002;

/* ZXG ADDED ------------------------- 1/3/2018 ---------------*/
%if &FCycle= Oct2018 and
	(&category=1470x and &service=211)
%then %do;
   %let ThisRatioMEAN=1.000;
   %put I am in avreage 1470 calculation;
 %end;

/* ZXG ADDED ------------------------- 1/3/2018 ---------------*/
%if &FCycle= Oct2018 and
	(&category=1960x and &service=211)
%then %let ThisRatioMEAN=1;

/* ZXG ADDED ------------------------- 1/10/2018 ---------------*/
%if &FCycle= Oct2018 and
	(&category=1221 and &service=310)
%then %let ThisRatioMEAN=1;

/* ZXG ADDED ------------------------- 1/10/2018 ---------------*/
%if &FCycle= Oct2018 and
	(&category=1252 and &service=310)
%then %let ThisRatioMEAN=1;



%if &FCycle= Oct2018 and
	(&category=1221 and &service=630)
	and MOS>='JUL2018'D
%then %let ThisRatioMEAN=0.999;

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

/* ZXG: newly added --------------------*/
%if &FCycle= Oct2020 and
	(&category=1480 and &service=551)
%then %do;
   %PUT NOTE: I AM HERE  in (1480,551)==============;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
/*	 lag_ProjectedFmap = lag(ProjectedFmap);*/
     if mos >'01Dec2019'd then ProjectedFmap = ProjectedFmap-0.09;
	 BaseFmap = ProjectedFmap;

     FmapMos= ProjectedFmap;
   run; 

%end;

%if &FCycle= Feb2021 and
	(&category=1480 and &service=775)
%then %do;
   %PUT NOTE: I AM HERE  in (1480,551)==============;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
/*	 lag_ProjectedFmap = lag(ProjectedFmap);*/
     if mos >'01Jun2019'd then ProjectedFmap = 0.4895;
	 BaseFmap = ProjectedFmap;
     FmapMos= ProjectedFmap;
   run; 

%end;

/*zxg: for cycle 2117 */
%if &FCycle= Feb2021 and (&category=1262 and &service=775) %then %do;
/*  proc sql;*/
/*    select ProjectedFmap into:famp_pred*/
/*    from FMAP.FmapRatio&category._&service*/
/*	where mos ='01May2021'd;*/
/*  quit;*/

   %put zxg is in cell (&category, &service) ; 
   data FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
		  if mos >='01Jul2019'd then ProjectedFmap = 0.7239; 
	 BaseFmap = ProjectedFmap;
     FmapMos= ProjectedFmap;
   run; 
		  
	
  %end;

  %if &FCycle= Feb2019 and (&category=1251 and &service=610) %then %do;
   %put NOTE: I am here in (1221,773)++++++++++++++++++++++++++++; 
   data FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
		if mos>='01Jan19'd then do;
		  FmapMOS =  BaseFmap;
          ProjectedFmap = BaseFmap;
		  FedShareValue = BaseFmap;
		end;
	  
  run;
  %end;
/*ZXGl for cycle 1924 in August 2019 */
%if &FCycle= Oct2019 and
	(&category=1222 and &service=310)
%then %do;
   %PUT NOTE: I AM HERE (&category,&service)+++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
/*	 FmapRatio  = 1.0000;*/
	 ProjectedFmapRatio  = 1.0000;
	 ProjectedFmap = FmapMOS;
	 if mos>="01Mar2019"d then  FedShareValue = FmapMOS;
   run; 

%end;

/*ZXGl for cycle 1924 in August 2019 */
%if &FCycle= Oct2019 and
	(&category=1251 and &service=310)
%then %do;
   %PUT NOTE: I AM HERE (&category,&service)+++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	  if mos>="01Dec2018"d then do;
       FedShareValue = FmapMOS;
	   ProjectedFmapRatio  = 1.0000;
	   ProjectedFmap = FmapMOS;
	 end;
   run; 

%end;


/*ZXGl for cycle 1924 in August 2019 */
%if &FCycle= Oct2019 and
	(&category=9999 and &service=310)
%then %do;
   %PUT NOTE: I AM HERE (&category,&service)+++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	  if mos>="01Jun2018"d then do;
	   put " i am here, i am here ++++++++++++";
/*	   FedShareValue = FmapMOS;*/
	   ProjectedFmapRatio  = 1.0000;
	   ProjectedFmap = 0.77243;
	 end;
   run; 

%end;

%if &FCycle= Oct2018 and
	(&category=1212 and &service=101)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 BaseFmap = 0.5;
	 FmapMOS = 0.5;
	 ProjectedFmap = 5;
	 if MOS>="01Dec2016"d then do;
       FedShareValue = FmapMOS;
       
	 end;
   run; 

%end;
/*ZXG: modified at 1/22/2018 ---------------------------------------------------------------------*/
%if &FCycle= Oct2018 and
	(&category=1280 and &service=290)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 BaseFmap = 0.5586417;
	 FmapMOS = 0.5586417;
	 ProjectedFmap = 0.5586417;
	 if MOS>="01Jul2017"d then do;
       FedShareValue = FmapMOS;
       
	 end;
   run; 

%end;

/*ZXG: modified at 1/25/2018 ---------------------------------------------------------------------*/
%if &FCycle= Oct2018 and
	(&category=1280 and &service=450)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 BaseFmap = 0.6437374;
	 FmapMOS = 0.6437374;
	 ProjectedFmap = 0.6437374;
	 if MOS>="01Jul2017"d then do;
       FedShareValue = FmapMOS;
       
	 end;
   run; 

%end;


%if &FCycle= Oct2018 and
	(&category=1280 and &service=453)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 if MOS>="01Jul2017"d then do;
       FedShareValue = 0.5000;
	   BaseFmap = 0.5000;
	   FmapMOS = 0.5000;
	   ProjectedFmap = 0.5000;
       
	 end;
   run; 

%end;

%if &FCycle= Oct2019 and
	(&category=1480 and &service=571)
%then %do;
   %PUT NOTE: I AM HERE (&category, &service)++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 if MOS>="01May2017"d then do;
       FedShareValue = 0.35500;
	   ProjectedFmap = 0.35500;
       FmapMOS = 0.35500;
	   BaseFmap = 0.35500;
       
	 end;
   run; 

%end;

/*ZXG, for cycle 2105 --------------------------- */
%if &FCycle= Oct2020 and
	(&category=1470 and &service=310)
%then %do;
   %PUT NOTE: I AM HERE (&category, &service)++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 if mos>='01Sep2019'd then do;
       ProjectedFmap = ProjectedFmap+0.01953;
       FmapMOS = ProjectedFmap;
	   BaseFmap = ProjectedFmap;
	 
	 end;
   run; 

%end;

%if &FCycle= Oct2020 and
	(&category=1470 and &service=551)
%then %do;
   %PUT NOTE: I AM HERE (&category, &service)++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 if mos>='01Dec2019'd and mos <='01mar2020'd then do;
       ProjectedFmap = ProjectedFmap+0.12938;
       FmapMOS = ProjectedFmap;
	   BaseFmap = ProjectedFmap;
	end;
	else do;
      ProjectedFmap = ProjectedFmap+0.11638;
       FmapMOS = ProjectedFmap;
	   BaseFmap = ProjectedFmap;
	 
	 end;
   run; 

%end;

%if &FCycle= Oct2020 and
	(&category=1262 and &service=775)
%then %do;
   %PUT NOTE: I AM HERE (&category, &service)++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 
       ProjectedFmap = ProjectedFmap+0.004;
       FmapMOS = ProjectedFmap;
	   BaseFmap = ProjectedFmap;
	run; 

%end;

%if &FCycle= Oct2018 and
	(&category=1280 and &service=731)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 BaseFmap = 0.6499994;
	 FmapMOS = 0.6499994;
	 ProjectedFmap = 0.6499994;
	 if MOS>="01Jul2017"d then do;
       FedShareValue = 0.6499994;
       
	 end;
   run; 

%end;


%if &FCycle= Oct2018 and
	(&category=1280 and &service=740)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 BaseFmap = 0.6346548;
	 FmapMOS = 0.6346548;
	 ProjectedFmap = 0.6346548;
	 if MOS>="01Jul2017"d then do;
       FedShareValue = 0.6346548;
       
	 end;
   run; 

%end;

/*zxg: 8/6/2018 added ----------------------------*/
%if &FCycle= Oct2018 and
	(&category=1222x and &service=211)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 
	  if mos>="01Jul2019"d and mos<="01Dec2019"d then do;
	   ProjectedFmap = 0.92788;
	   FmapMOS = ProjectedFmap;
/*	   BaseFmap = ProjectedFmap;*/
	   FedShareValue = ProjectedFmap;
       
	 end;
   run; 
	 
   run; 

%end;



%if &FCycle= Oct2018 and
	(&category=1271 and &service=375)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 if MOS>="01Jun2016"d then do;
	   ProjectedFmap =FmapMOS;
	   FedShareValue = ProjectedFmap;
       
	 end;
   run; 

%end;

	%SetConversionRatio1(&Category, &Service, AVERAGE);

%if &FCycle= Oct2018 and (&category=1470x and &service=211) %then %do;
   %PUT NOTE: I AM HERE in 1470 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 ProjectedFmap = ProjectedFmap;
	 BaseFmap = ProjectedFmap;
	 FmapMOS = ProjectedFmap;
   run; 

 %end;

/*ZXG: modified at 1/25/2018 --------------------------*/

%if &FCycle= Oct2018 and
	(&category=1271 and &service=413)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
/*	 ProjectedFmap = 0.5;*/
/*	 FmapMOS = ProjectedFmap;*/
/*	 BaseFmap = ProjectedFmap;*/
	 if MOS>="01May2017"d then do;
	   ProjectedFmap = 0.5;
	   FmapMOS = ProjectedFmap;
	   BaseFmap = ProjectedFmap;
	   FedShareValue = ProjectedFmap;
       
	 end;
   run; 

%end;


/*ZXG: modified at 1/7/2019 --------------------------*/

%if &FCycle= Feb2019 and
	(&category=1271 and &service=671)
%then %do;
   %PUT NOTE: I AM HERE in 671 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
     ProjectedFmapRatio = 1.06659;
     ProjectedFmap = ProjectedFmapRatio*BaseFmap;
	 FedShareValue = ProjectedFmap;
     if MOS>"01Feb2018"d then   FmapRatio = ProjectedFmapRatio;
   run; 

%end;

/*ZXG: modified at 1/25/2018 --------------------------*/
%if &FCycle= Oct2018 and
	(&category=1998 and &service=211)
%then %do;
   %PUT NOTE: I AM HERE ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++;
   DATA FMAP.FmapRatio&category._&service;
     set FMAP.FmapRatio&category._&service;
	 
	 
	 if MOS>"01Jan2017"d then do;
	   ProjectedFmap = 0.500;
	   FmapMOS = ProjectedFmap;
	   BaseFmap = ProjectedFmap;
	   FedShareValue = ProjectedFmap;
       
	 end;
   run; 

%end;

%MEND;
/*
%MethodRegistration(&pFMAP, FmapForecastAverage);
*/

/* %FmapForecastAverage(ThisCycle=0724, category=1100, service=005, FirstDate='01JUL2003'd); */

