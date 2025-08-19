/*
~ METHOD_NAME                      - PrepareBFAMpweights
~ vCLASS_ID                        - 7 
~ EXEC_CALL                        - 0
~ INPUT_IMPLEMENTATION_FORM        - NA 
~ METHOD_RETURN_VALUE              - NA 
~ RETURN_IMPLEMENTATION_FORM       - NA 
~ METHOD_LABEL                     - PrepareBFAMpweights
~ METHOD_DESCRIPTION               - PrepareBFAMpweights
~ PARAMETER_NAME                   - FmapVersion
~ PARAMETER_VALUE                  - NULL
~ PROGRAMMER                       - Shidong Zhang
~ DATE_CREATED                     - 2008/03/26
*/
%MACRO PrepareBFAMpweights;

	%LoadFmap_MopDB;
    /*ZXG:
      Create table Fmap.Fmap_mop contain the policy level FMAP, the table is populated from MainDM.Fact_FmapMopHistory

	*/
	%BaseFmapData;

	PROC SQL NOPRINT;
		CREATE TABLE FMAP.GrandSumFmapTotal AS
		SELECT /*Scheme_ID AS Scheme, */
				PaymentMonth AS MOP, 
				ForecastMeg AS category, 
				ForecastSvc AS Service, 
				SUM(AfrsExpenditure) AS GrandTotal
		FROM Fmap.BaseFmapData
		WHERE SUBSTR(PaymentMonth, 3, 2) NOT IN ('25', '99')
		GROUP BY  category, Service, MOP
		ORDER BY category, Service, MOP;
	QUIT;

	PROC SQL NOPRINT;
		CREATE TABLE FMAP.SumFmapTotal AS
		SELECT /*Scheme_ID AS Scheme, */ 
				PaymentMonth AS MOP, 
				ForecastMeg AS category, 
				ForecastSvc AS Service, 
				Afrs_Sof_ID AS SOF, 
				SUM(AfrsExpenditure) AS Total
		FROM Fmap.BaseFmapData
		WHERE SUBSTR(PaymentMonth, 3, 2) NOT IN ('25', '99')
		GROUP BY  category, Service, MOP, SOF
		ORDER BY category, Service, MOP, SOF;
	QUIT;

	PROC SQL NOPRINT;
		CREATE TABLE FMAP.BaseFmapWeights AS
		SELECT a.*, b.GrandTotal, a.Total/b.GrandTotal AS weights
		FROM FMAP.SumFmapTotal AS a
		LEFT JOIN FMAP.GrandSumFmapTotal AS b
		ON a.category EQ b.category AND
			a.Service EQ b.Service AND
			a.MOP Eq b.MOP
		ORDER BY category, Service, MOP, SOF;
	QUIT;

	%CovertFiscalYrToCalender(infile=FMAP.BaseFmapWeights, outfile=, Column=MOP, NewColumn=MOP1);

	DATA FMAP.BaseFmapWeights(RENAME=(MOP1=MOP));
		SET FMAP.BaseFmapWeights;
		DROP MOP;
	RUN; 
%MEND;

/*return to MainFmap >  MOP_FMAP*/

/*
%MethodRegistration(&pFMAP, PrepareBFAMpweights);
*/
