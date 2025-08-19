title 'VwCode.Vw_CycleCellMap';
proc print data = VwCode.Vw_CycleCellMap (obs =100);
run; 

title 'VwExel.Vw_ForLagExpMos';
proc print data = VwExel.Vw_ForLagExpMos (obs =100);
run; 

title 'MainDm.Dim_For_PtCellType';
proc print data = MainDm.Dim_For_PtCellType (obs =100);
run; 

title 'MainDm.Map_For_Cell';
proc print data = MainDm.Map_For_Cell (obs =100);
run; 

title 'MainDm.Map_For_FactSeries';
proc print data = MainDm.Map_For_FactSeries (obs =10);
run; 


title 'MainDm.Dim_For_ElementIdentifier';
proc print data = MainDm.Dim_For_ElementIdentifier (obs =10);
run; 

title 'MainDm.Dim_For_FactType';
proc print data = MainDm.Dim_For_FactType (obs =10);
run; 

title 'VwExel.Vw_IerElgMcEnrollPctMos';
proc print data = VwExel.Vw_IerElgMcEnrollPctMos (obs =100);
run; 


TITLE 'Source.MaPredictedEligible';
proc print data = Source.MaPredictedEligible (obs =1000);
run; 



title ' MainDm.Dim_For_Meg';
proc print data =  MainDm.Dim_For_Meg (obs =100);
run; 

title 'VwExel.Vw_ForLagElgMos';
proc print data = VwExel.Vw_ForLagElgMos (obs =100);
run; 

title 'MainDm.Fact_For_Eligible';
proc print data = MainDm.Fact_For_Eligible (obs =100);
run; 

title 'Source.MaPredictedFundAllocation';
proc print data = Source.MaPredictedFundAllocation;
run; 

title " MainDm.Dim_FundType";
proc print data =  MainDm.Dim_FundType (obs =100);
run; 

title ' VwProc.Vw_ForPercapMap';
proc print data =  VwProc.Vw_ForPercapMap (obs =100);
run; 

title 'Source.CellStructureAssociations';
proc print data = Source.CellStructureAssociations;
run; 

title 'MainDm.Fact_For_FundAllocation';
proc print data = MainDm.Fact_For_FundAllocation (obs =100);
run; 


title 'MainDm.FACT_FOR_PERCAP';
proc print data = MainDm.FACT_FOR_PERCAP(obs =1000);
run; 

proc contents data = MainDm.Map_For_FactSeries;
run; 

/*
Note: table MainDm.Dim_For_FactType, MainDm.Map_For_FactSeries, and table MainDm.Dim_For_ElementIdentifier are the 
      tables taht work together functioning as xwalk table. 

     table VwExel.Vw_ForLagElgMos contains the lagged eligible 
     table VwExel.Vw_ForLagExpMos contains the lagged expenditure. 



*/
