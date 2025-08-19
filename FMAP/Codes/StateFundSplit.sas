/*
~ METHOD_NAME                      - StateFundSplit
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - String 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - StateFundSplit
~ METHOD_DESCRIPTION               - State Fund Split into G and T
~ PARAMETER_NAME                   - 
~ PARAMETER_VALUE                  - 
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/
%MACRO StateFundSplit;

/*Clean up missing values in the fed set*/
Data FMAP.LoadPredicted_FedShare; 
  Set FMAP.LoadPredicted_FedShare;
  Array nums _numeric_;
  Do over nums;
    If nums=. then nums=0;
  End;
Run;

/*Drop tables*/	
 	%DropTable(FMAP.LoadPredicted_StateShare);
	%DropTable(FMAP.LoadPredicted_GShare);
	%DropTable(FMAP.LoadPredicted_NShare);
	%DropTable(FMAP.LoadPredicted_LShare);

/*State share*/
DATA FMAP.LoadPredicted_StateShare;
  SET FMAP.LoadPredicted_FedShare;
  FundAllocationType='G';

  /*ForecastPredictedShare_oldState=1-ForecastPredictedShare;*/
  IF ForecastPredictedShare < 1 And ForecastPredictedShare > 0 Then Do; 
    ForecastPredictedShare=1-ForecastPredictedShare;
  End;
  ELSE IF ForecastPredictedShare >= 1 Then Do; 
	ForecastPredictedShare=0; 
  End; 
  ELSE IF  ForecastPredictedShare <= 0 Then Do; 
	ForecastPredictedShare=1; End;
  ELSE Do; 
   ForecastPredictedShare=1-ForecastPredictedShare; 
  End;
RUN;


/*State share G*/
DATA FMAP.LoadPredicted_GShare;
  SET FMAP.LoadPredicted_StateShare;
  FundAllocationType='G';
  IF ForecastSvc = '101' Then /*state share .4 local share .6*/
	Do; 
	  ForecastPredictedShare=(ForecastPredictedShare ) * 0.4; 
	End;  
	ELSE IF ForecastSvc = '350' Then Do; /*all local share*/
		ForecastPredictedShare=0; 
		ForecastConversionRatio=0;
	End;
	ELSE Do; 
      ForecastPredictedShare=ForecastPredictedShare; 
    End; 

		/*change = (ForecastPredictedShare_old - ForecastPredictedShare) / ForecastPredictedShare_old;	*/
RUN;


/*Local State Share*/
/*Service 310 has been used to create history for 350. 350 now has its own history,
	so is now stand-alone 10-12-15*/
DATA FMAP.LoadPredicted_LShare;
  SET FMAP.LoadPredicted_StateShare /*(WHERE=(ForecastSvc NOT IN ('350')))*/;
  FundAllocationType='L';

  /*ForecastPredictedShare_old=1-ForecastPredictedShare;*/
  IF ForecastSvc = '101' Then  Do;/*state share .4 local share .6*/
			ForecastPredictedShare=(ForecastPredictedShare) * 0.6; 
			End;
		ELSE IF ForecastSvc = '350' Then Do; /*all local share*/
			ForecastPredictedShare=ForecastPredictedShare; 
			End; 
		ELSE Do; 
			ForecastPredictedShare=0; 
			ForecastConversionRatio=0;	
		End;
		/*change = (ForecastPredictedShare_old - ForecastPredictedShare) / ForecastPredictedShare_old;	*/		
RUN;

/*350 Local State from 310 State Share*//*NOT NEEDED IF 350 HAS HISTORY*/
/*
DATA MakeUp_L;
		SET FMAP.LoadPredicted_StateShare(WHERE=(ForecastSvc IN ('310')));
		IF ForecastSvc = '310' THEN ForecastSvc='350';
		FundAllocationType='L';
RUN;
*/

/*SNAF for history*/
DATA FMAP.LoadPredicted_NShare;
		SET FMAP.LoadPredicted_StateShare;
			FundAllocationType='N';
			ForecastPredictedShare=0; 
			ForecastConversionRatio=0;
RUN;


	/*****************************************************************************/

/*Merge 350 back to local*//*NOT NEEDED IF 350 HAS HISTORY*/
/*
PROC APPEND BASE=FMAP.LoadPredicted_LShare DATA=MakeUp_L;
RUN;
*/

	/*****************************************************************************/
%DropTable(FMAP.LoadPredictedShare);
/*Put all the type together*/
PROC APPEND BASE=FMAP.LoadPredictedShare DATA=FMAP.LoadPredicted_FedShare;
RUN;

PROC APPEND BASE=FMAP.LoadPredictedShare DATA=FMAP.LoadPredicted_GShare;
RUN;

PROC APPEND BASE=FMAP.LoadPredictedShare DATA=FMAP.LoadPredicted_LShare;
RUN;

PROC APPEND BASE=FMAP.LoadPredictedShare DATA=FMAP.LoadPredicted_NShare;
RUN;

PROC SORT DATA=FMAP.LoadPredictedShare;
	BY ForecastMeg ForecastSvc ServiceMonth FundAllocationType; 
RUN;

	/*****************************************************************************/

%MEND;

/*
%MethodRegistration(&pFMAP, StateFundSplit);
*/
