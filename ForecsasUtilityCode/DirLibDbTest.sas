
%MACRO DirLibDb(ThisRootPath);

%LOCAL LoadTable ThisLibDir ThisExternelFile;

	%LET ThisLibDir=&ThisRootPath.SourceInformation\DirLibDb\;
	%LET ThisExternelFile=&ThisRootPath.SourceInformation\ExternelFile\;
	%LET ThisMain=&ThisRootPath.SourceInformation\Main\;

	%LET LoadTable=Directory Directory2 Library Table columns vClass Parameters;

	%CLOSEALLOPENFILES;

	%LoadExcelTables(&ThisLibDir, &loadTable);

	%MakePhysicalDirectory2(&ThisRootPath, 0);

	%MakeLibrary(work, 0);

	%MakeTables;
	%MakeForeignConstraints;

	%KernelLoadDirLibDB(&ThisRootPath, &LoadTable);

	%AssignPointers;
	%SetNewPointer(pDirLibDb, &ThisLibDir, 0);
	%SetNewPointer(pThisRootPath, &ThisRootPath, 0);
	%SetNewPointer(pExternelFile, &ThisExternelFile, 0);
	%SetNewPointer(pMain, &ThisMain, 0);

	%InitializeSequence;
	
	%StartLoading;
	%RegisterAllMethods;

	%MakePhysicalDirectory2(&pDProcessFiles, 1);

	%MakeLibrary(work, 1);

	%AssignPointers;
	%CycleVersionParameters;

	%Tplt4in1;
	
	%SYSEXEC(Copy "&pExternelFile" "&pDExternel");
	%SYSEXEC(Copy "&pMain" "&pDMainPrograms");

	%PUT;
	%PUT------------------------------------------------------------------------;
	%PUT;
	%PUT NOTE:(SD)                  The END of Deployment;   
		%PUT;
	%PUT------------------------------------------------------------------------;
	%PUT;
%MEND;




%LET ThisCycle=1712; 

%LET MSOfficeBit=64;

%LET ThisRootPath=\\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle&ThisCycle._zxg\Milliman\;
%put &ThisRootPath.sourceInformation;
OPTIONS NOXWAIT MPRINT MAUTOSOURCE MRECALL SASAUTOS=("&ThisRootPath.sourceInformation\DirLibDb" SASAUTOS) extendobscounter=no;

%DirLibDb(&ThisRootPath);
