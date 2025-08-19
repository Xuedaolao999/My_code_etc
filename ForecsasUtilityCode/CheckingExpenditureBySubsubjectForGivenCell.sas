/**************************************************************
* Author: Xingguo Zhang
* Date: 9/21/2017
* Purpose: To analyze the total expenditure by subsubject
**************************************************************/

dm 'log' clear;

%let meg = 1621;
%let svc = 551;

data exp_&meg._&svc;
  set Vwshare.Vw_afrs_lagexpfs;
  where AfrsMeg = "&meg" and AfrsSvc  = "&svc" and AfrsCycle = '1912';
run; 

proc print data = exp_&meg._&svc (obs =10);
  where ServiceMonth>=201707;
run; 

proc sql;
 create table exp_by_Subsubject_&meg._&svc as 
 select a.SubSubObject,b.Cdtbl_SubSubObject_Desc,ServiceMonth,sum(a.AfrsExpenditure) as exp
 from exp_&meg._&svc as a 
 inner join (select distinct SubSubObject, Cdtbl_SubSubObject_Desc 
             from Etlmd.Ssoxwalk
            ) as b
   on a.SubSubObject = b.SubSubObject
 where ServiceMonth>=201301
 group by a.SubSubObject,b.Cdtbl_SubSubObject_Desc,a.ServiceMonth
 order by SubSubObject,ServiceMonth;
 quit;


proc sql;
  select distinct Cdtbl_SubSubObject_Desc into:subsubobject seprated by ','
  from exp_by_Subsubject_&meg._&svc;
quit; 

%put &subsubobject;

%macro aggregate;
  %local i;
  %local statment = ;
  %let i = 1;
  %let ssb = %scan(%bquote(&subsubobject),&i,%str(,));
  %put NOTE: ssb IS &SSB; 
  
  %do %while (%length(&ssb)>0);
    proc sql;
      create table t&i as 
      select ServiceMonth, exp as exp&i label ="&ssb"
      from exp_by_Subsubject_&meg._&svc
      where Cdtbl_SubSubObject_Desc = "&ssb";
    quit;
   
   %let statment = &statment t&i;
   %let i =%eval(&i+1);
   %let ssb = %scan(%bquote(&subsubobject),&i,%str(,));
  %end;
  
  data all_&meg._&svc;
    merge %str(&statment;);
	by ServiceMonth;
  run; 

  proc datasets lib = work;
   delete %str(&statment;);
%mend;

%aggregate; 

title "all_&meg._&svc";
proc print data = all_&meg._&svc label;
run; 
