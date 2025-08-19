
%MACRO DirLibDb(ThisRootPath);

%LOCAL LoadTable ThisLibDir ThisExternelFile;

	%LET ThisLibDir=&ThisRootPath.SourceInformation\DirLibDb\;
	%LET ThisExternelFile=&ThisRootPath.SourceInformation\ExternelFile\;
	%LET ThisMain=&ThisRootPath.SourceInformation\Main\;

	%LET LoadTable=Directory Directory2 Library Table columns vClass Parameters;

	%CLOSEALLOPENFILES;

	%*%LoadExcelTables(&ThisLibDir, &loadTable);  /* for debug purpose, commented this macro, similarly in the following*/
	

	%*%MakePhysicalDirectory2(&ThisRootPath, 0);
    /* Note: With current excel file parameter, the folder Forecast Application, the folder Forecast Process Specific Files,
	         and QC will be produced within the Milliman folder; under the folder of Forecast Application, the folder of AppTemp, Kernel
	         are also created, because the ParentDirID is 1, they get the value from DirectoryId 1, which is used ParetentDirId in the 
	         macro MakeDir. 
	*/
	
	%*%MakeLibrary(work, 0);
    /* this create the libname Kernel which connect the folder \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_z
            xg\Milliman\Forecast Application\Kernel\ 
	*/
	

	%*%MakeTables;
    /*Note: Create tables Columns, Directory, Directory2,Library,Root,etc all the tables listed in the work.table names where libraryId = 1*/
	
	%*%MakeForeignConstraints;
    /* create the table constrains for the table created above*/
    
	%*%KernelLoadDirLibDB(&ThisRootPath, &LoadTable);
    /* Note: populate the corresponding tables in SAS Kernel library by the same name table from SAS Work library:
             Directory, Directory2, Library, Table, columns, vClass, Parameters. As a result, the table in Kernel is 
	         the idential copy of the table in Work Library
	*/
	

	%*%AssignPointers;
    /* Note: This creates the global macor varible based on the table Kernel.Parameters (from work.Parameter). For example,
	         macro variable pDataCycle, its value is 1712,
	         macro variable FirstDateOfAcutalData, its value is "01Jul2010"d
	         macro PPRIORFORECASTCYCLE, its value is  1705
             etc. 
    */
	
	%*%SetNewPointer(pDirLibDb, &ThisLibDir, 0); /* -----   step 1  -----  */
   /* NOTE: this provides the true value "\\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\DirLibDb\"
	        to the parater name "pDirLibDb" by replacing the macro &pThisRootPath in the folder definition in the paramter table from excel file LIbrary.xls tab PARAMETERS 
            In fact, from the above macro AssignPointers, the pDirLibDb is a macro variable, its value is  the path of  the folder.
	*/
    
	%*%SetNewPointer(pThisRootPath, &ThisRootPath, 0); /* -----   step 2  -----  */
   /* Note: this creates a gloabl macro variable pThisRootPath whose value is value of &ThisRootPath; in our sinario, it is 
			\\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\

	*/


	%*%SetNewPointer(pExternelFile, &ThisExternelFile, 0); /* -----   step 3  -----  */
   /* Note: This is similar to step 1, this provide the value to the golobal variable pExternelFile, its value is 
	        \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\ExternelFile\
	*/

	%*%SetNewPointer(pMain, &ThisMain, 0); /* -----   step 4  -----  */
    /* Note: This is similar to step1, this provides teh value to the global variable pMain, its value is 
             \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\Main
      
	*/
	

	%*%InitializeSequence;
    /* Note: this execution populates the Kernel.Sequence table with sequence names are 
	         method and methodVariable respectively.

	*/
	

	
	%*%StartLoading;
   /* Note: This creates a SAS code StartLoadKernel.sas in the following folder:
	        \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Application\StartLoad.
	        By the way, this is a creative method can be borrowed to use

	*/
	

	%*%RegisterAllMethods;
    /* Note: similar to step 1, it provide the value to the macro variable whose name is the value of vClass_name prefixed with p,
	         For exmaple, a vClass_name is Fmap, the corresponding macro variable is pFmap; This execution also copy file from 
	         \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Application\Programs\Adult_Kid_Graph_264.sas 
	         To
	         \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Application\Programs\ProgramRecycle\Adult_Kid_Graph_264.sas
	        and other activities. The folder ~\ProgramRecycle\stored the copy files you can go back to if needed. 



	*/
	
  

	%*%MakePhysicalDirectory2(&pDProcessFiles, 1);
    /* Note: this execution create the folder Cycle1712 within folder 
	   \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Process Specific Files\;
      under folder Cycle1712, the folder Version A is created; within version A folder, there are folders like Eligibles, ETL, External, 
	  FMAP, and other folders totally 19 folders. At this stage,these 19 folders are empty.

	*/
	
	%*%MakeLibrary(work, 1);
	 /* this create the libname TRACK which connect the folder 
	    \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Process Specific Files\Cycle 1712\Version A\Tracking\;
	    similar for other  folders. 
	*/
	

	%*%AssignPointers;
   /* Note: similar as above for the same macro execution */
	

	%*%CycleVersionParameters;
   /* this creates a excel file 
	\\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Application\General Purpose\CycleVersionParameters.xls

	*/
	

	%*%Tplt4in1;
    /*
     Note: creates a five panel template
	*/

	
	
    /* ------------------------------------------- i am here --------------------------------*/
   
	%SYSEXEC(Copy "&pExternelFile" "&pDExternel");
	 /* NOTE: copy file from \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\ExternelFile
	        To
	        \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Process Specific Files\Cycle 1712\Version A\Externel\

 	*/

	%SYSEXEC(Copy "&pMain" "&pDMainPrograms");
     /* NOTE: copy file from \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\SourceInformation\Main\

	        To
	        \\ofm.wa.lcl\gwu\FC\SECURE\HMSVC\MedicaidForecast\ForecastOFM\Production\NwCycle1712_zxg\Milliman\Forecast Application\MainPrograms\


 	*/
  
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
