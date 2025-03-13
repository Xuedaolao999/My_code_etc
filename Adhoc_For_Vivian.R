# adding the header to test the file 
# testing again with my github again 
# third time testing ------------------------------------------
library(rJava)
library(xlsx)
library(dplyr)
dat<-read.xlsx('I:\\Copy of Data to reshape.xlsx',sheetName ='data',header=TRUE)
beg<-min(dat$Start_year)
end<-max(dat$End_year)
# dat2<-data.frame(matrix(ncol=2,nrow=0))
# names(dat2)<-c('year','status')



##
x<-beg:(end+1)
##get the earliest start and end date for each group
# beg1<-min(dat$Start_year[dat$id==1])
# end1<-max(dat$End_year[dat$id==1])
# beg2<-min(dat$Start_year[dat$id==2])
# end2<-max(dat$End_year[dat$id==2])

range<-dat%>%group_by(id)%>%mutate(beg_grp=min(Start_year),end_grp=max(End_year))%>%select(id,beg_grp,end_grp)%>%unique()%>%as.data.frame()

fin<-data.frame(matrix(ncol=3,nrow=0))

for (e in unique(range$id)) {
  lb<-range[range$id==e,'beg_grp']
  ub<-range[range$id==e,'end_grp']
  print(lb)
  print(ub)
  for (ele in x) {
    if (ele>=lb && ele<=ub) {
      val<-c(e,ele,'yes')
      fin<-rbind(fin,val,stringsAsFactors=FALSE)
      #print(val)
    } 
    else {
      val<-c(e,ele,'no')
      #print(val)
      fin<-rbind(fin,val,stringsAsFactors=FALSE)
    }
  }
  
  
}

names(fin)<-c('id','year','status')

library(tidyr)
fin1<-fin%>%spread(id,status)
fin2<-t(fin1)
colnames(fin2)<-fin2['year',]
fin3<-fin2[-1,]

## aonther format
fin3
fin4<-cbind(rownames(fin3),fin3)
colnames(fin4)[1]<-'Id'
fin4 

write.xlsx(fin4,"I:\\reshape.xlsx",col.names=TRUE,row.names = FALSE)

