library(data.table)
library(magrittr)

if(!file.exists("data"))
    system("mkdir data")
file="pmc_result.txt" # downloaded from https://www.ncbi.nlm.nih.gov/pmc/?term=fgsea on 18/4/24
data=fread(file,header=FALSE)
setnames(data,"V1","PMCID")
data[,xml:=paste0("https://www.ncbi.nlm.nih.gov/research/bionlp/RESTful/pmcoa.cgi/BioC_xml/",PMCID,"/unicode")]
data[,outfile:=paste0(PMCID,".xml")]
data[,cmd:=paste0("cd data && wget -nc ",xml," -O ",outfile)]
files_found=list.files("data",full=FALSE,pattern=".xml$")
data[,downloaded:=outfile %in% files_found]
table(data$downloaded)

for(i in which(!data$downloaded)) {
  system(data$cmd[i])
}

## how many files successful?
files_found=list.files("data",full=TRUE,pattern=".xml$")
info=file.info(files_found)
sizes=file.info(files_found)$size
hist(log(sizes+1),breaks=1000)
files_nonempty= sizes > 0
message("found ",length(files_found)," / wanted ",nrow(data))
message("with data ",sum(files_nonempty)," / wanted ",nrow(data))

preranked1=system("grep -l 'fgsea function' data/*",intern=TRUE)  %>% gsub("data/|.xml","",.)
preranked2=system("grep -l 'function fgsea' data/*",intern=TRUE)  %>% gsub("data/|.xml","",.)
preranked_any=system("grep -l 'fgsea' data/*",intern=TRUE)  %>% gsub("data/|.xml","",.)
label1=system("grep -l 'fgseaLabel function' data/*",intern=TRUE)  %>% gsub("data/|.xml","",.)
label2=system("grep -l 'function fgseaLabel' data/*",intern=TRUE)  %>% gsub("data/|.xml","",.)
label_any=system("grep -l 'fgseaLabel' data/*",intern=TRUE)  %>% gsub("data/|.xml","",.)

## find years
## years=system("grep -o ' 20[0-9][0-9] ' pmc_full.txt",intern=TRUE)
## pmcid=system("grep -o 'PMC[0-9][0-9]*' pmc_full.txt", intern=TRUE)
## years=system("grep -o '<date>20[0-9]*</date>' data/*", intern=TRUE)
years=system("grep -o '<infon key=\"year\">20[0-9][0-9]</infon>' data/*", intern=TRUE) 
dt = gsub("data/|.xml|<infon key=\"year\">|</infon>","",years) %>% tstrsplit(., ":") %>% as.data.table()
setnames(dt,c("pmcid","datestr"))
dt=dt[!duplicated(pmcid)] # because the first year relates to the publication, the next to the publication of its references
dt[,year:=as.numeric(datestr)]

dt[,fgsea_function:=pmcid %in% c(preranked1,preranked2)]
dt[,fgseaLabel_function:=pmcid %in% c(label1,label2)]
dt[,fgsea_any:=pmcid %in% c(preranked_any)]
dt[,fgseaLabel_any:=pmcid %in% c(label_any)]

with(dt,sum(fgsea_function))
with(dt,sum(fgseaLabel_function))

library(ggplot2)
library(cowplot)
theme_set(theme_cowplot())
bottom=ggplot(dt[fgsea_function==TRUE | fgseaLabel_function==TRUE], aes(x=year,fill=fgseaLabel_function)) + geom_histogram(binwidth=1,col="grey") + background_grid(major="y") + scale_fill_discrete("papers report gseaLabel\nfunction or gsea function")
top=ggplot(dt[], aes(x=year,fill=fgseaLabel_any)) + geom_histogram(binwidth=1,col="grey") + background_grid(major="y") + scale_fill_discrete("papers report\ngseaLabel at all")
plot_grid(top,bottom,ncol=1)
