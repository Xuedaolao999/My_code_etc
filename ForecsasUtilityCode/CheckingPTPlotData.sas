
/* The following is checking the Fratio and where it is missing */


proc sql;
select *
from pmtrend.ModelInput
/*				  set Fratio = 1.29972*/
where /*mos <='01Nov2016'd and mos>='01Oct2016'd*/
      category= "1350" and Service= "422";
quit;

%macro CreatContMonth(start = 201607,end = 201906);
 data mon;
   first_of_month = mdy(%substr(&start,5,2),1,%substr(&start,1,4));
   do until (first_of_month > mdy(%substr(&end,5,2),1,%substr(&end,1,4)));
      output;
      first_of_month = intnx('month',first_of_month,1);
      end;
 run;


 data ConMonth;
   set mon;
   mon = month(first_of_month);
   if mon< = 9 then do;
     mon1 = '0'||trim(left(mon));
   end;
   else mon1 = mon;
   yr = year(first_of_month);
   newMos= input(yr||trim(left(mon1)),20.);
   drop mon yr mon1 first_of_month;
 run;

 proc datasets lib= work;
  delete mon;
 quit;
%mend CreatContMonth;


proc sql noprint;
     create table test as 
     select distinct a.forecastMeg,a.forecastSvc,PrimaryTrendCellType,a.MaPredictedPercap,a.ServiceMonth, b.NewMos
     from Mapredictedpercap (where = (forecastMeg = "&Meg" and forecastSvc = "&Svc" and upcase(PrimaryTrendCellType) = %upcase("&CellType")))as a 
     right join ConMonth as b 
       on a.ServiceMonth = b.newMos
     where a.MaPredictedPercap is missing
     order by a.ServiceMonth;
   quit;
  
