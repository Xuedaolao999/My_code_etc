/*!!!RunFMAP is the master macro. Make sure to set all variables before running!!!*/

/**********Location: RunFMAP, Line 23**********/
********************************************************************
* Variable assignments;
%let path2whole = %sysfunc(pathname(LAGFCTR));
%put &path2whole;		* Check in log if path is correct;
%LET ThisFmapVersion=FID32; /*****normally should be FID32 - enhanced FMAP .88;  set to FID82 for 1280 - enhanced FMAP .65*****/
%LET PassParameter1=; /*This sets &test to NULL*/
%LET PassParameter5=&ThisFmapVersion;
%let FCycle=Oct2017;


%Global Cutoff RegressionStart GraphStart JumpOff FmapVersion;
%LET Cutoff="01JAN2016"d;	/* DEFAULT date used to start date for the FMAP ratio average and SOF weight regression - ForecastStart from ExParameters ***OVERRIDES this***/
/*%let RegressionStart='01JAN2016'd;*/	/*the start date for the SOF weight regression - ***ONLY USE IF DIFFERENT PERIOD IS NEEDED FOR WEIGHT ESTIMATION***/
/*%let GraphStart='01JAN2016'd;*/	/*sets the the first date for the graphs - **ONLY USE AS NEEDED**. GRAPH WILL USE ForecastStart BY DEFAULT*/
%let GraphStart=;
%let JumpOff='01MAR2017'd;		/*first date of projection - ***ONLY USED TO SET REFERENCE LINE ON GRAPH***/
%LET FmapVersion=FID32; /*****normally should be FID32 - enhanced FMAP .88;  set to FID82 for 1280 - enhanced FMAP .65*****/
********************************************************************;

/*!!! Listing of Overrides: The following macros contain hard codes to be aware of. Details below!!!

FmapBaseData
CalcualteFmapWeights
ForecastFmap
FmapForecastAverage*/

/**********Location: FmapBaseData, Line 119**********/

/*fix problem with declining too much in Dec*/
%if	(&category=1222 and &service=310) or
	(&category=1222 and &service=333) or
	(&category=1221 and &service=333)
%then %do;
	data FMAP.FmapMos&category._&service;
		set FMAP.FmapMos&category._&service;
		LagValue = Lag(FmapMOS);
			if PaymentMonth = '01DEC16'd then FmapMOS = LagValue;
			if PaymentMonth = '01DEC17'd then FmapMOS = LagValue;
			if PaymentMonth = '01DEC18'd then FmapMOS = LagValue;
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
	data FMAP.FmapMos&category._&service;
		set FMAP.FmapMos&category._&service;
		LagValue = Lag(FmapMOS);
			if PaymentMonth = '01NOV16'd then FmapMOS = LagValue;
			if PaymentMonth = '01DEC16'd then FmapMOS = LagValue;
			if PaymentMonth = '01NOV17'd then FmapMOS = LagValue;			
			if PaymentMonth = '01DEC17'd then FmapMOS = LagValue;
			if PaymentMonth = '01NOV18'd then FmapMOS = LagValue;				
			if PaymentMonth = '01DEC18'd then FmapMOS = LagValue;
		drop LagValue;	
	run;
%end;



/**********Location: CalcualteFmapWeights, Line 481**********/
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


/**********Location: CalcualteFmapWeights, Line 517**********/
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
/*END SPECIAL ACA PATCH*/



/**********Location: FmapForecastAverage, Line 59**********/
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



/**********Location: ForecastFmap, Line 214**********/
/*####################################################################################################*/
/*Limit ACA Expansion to .93 in CY2019 IN JAN2019*/
%if (&category=1221 and &service=671) or
	(&category=1222 and &service=771)
%then %do;
	data FMAP.FmapRatio&category._&service;
		set FMAP.FmapRatio&category._&service;
			if mos >= '01JAN19'd then FedShareValue = Min(0.93, FedShareValue);
	run;
%end;

/*Limit ACA Expansion to .93 in CY2019 IN FEB2019*/
%if (&category=1221 and &service=336) or 
	(&category=1221 and &service=350) or 
	(&category=1221 and &service=610) or
	(&category=1221 and &service=630) or
	(&category=1221 and &service=211) or
	(&category=1222 and &service=221)
%then %do;
	data FMAP.FmapRatio&category._&service;
		set FMAP.FmapRatio&category._&service;
			if mos >= '01FEB19'd then FedShareValue = Min(0.93, FedShareValue);
	run;
%end;
/*END SPECIAL ACA PATCH*/
/*####################################################################################################*/



