library(data.table)
sizes_dt <- fread("NSCH_data/01_original_sizes.csv")
names_list <- list()
for(dtype in c("var","define")){
  names_list[[dtype]] <- sizes_dt[
    data_type==dtype, fread(out.csv), by=year]
}
names_list
var_autism <- names_list$var[grep("autism", desc, ignore.case = TRUE)]
dcast(var_autism, year ~ variable)

year_summary <- function(year){
  setkey(data.table(year))[, .(
    cluster=if(.N==1)
      as.character(year)
    else sprintf("%d–%d",year[1],year[.N])
  ), by=.(start=cumsum(c(TRUE,diff(year)>1)))
  ][, paste(cluster, collapse=",")]
}
years_by <- function(DT, cname){
  if(missing(cname))cname <- setdiff(names(DT),"year")
  DT[, .(
    years=year_summary(year)
  ), keyby=cname]
}
years_by(var_autism, "variable")
years_by(var_autism, "desc")
years_by(var_autism)

years_by(names_list$var[desc=="Family Structure"])
years_by(names_list$var[variable=="k6q71_r"])

var_list <- list(
  family=names_list$var[desc=="Family Structure"],
  interest_curiosity=names_list$var[variable=="k6q71_r"],
  autism=names_list$var[variable=="k2q35a"])
setkey(names_list$define, year, variable)
surveys_meta <- setkey(sizes_dt[data_type=="surveys"], year)
surveys_meta[, .(year, rows, cols)]
for(vname in names(var_list)){
  year_var <- setkey(var_list[[vname]], year, variable)
  title_list <- list()
  for(title_var in c("variable","desc")){
    ydt <- years_by(year_var, title_var)
    title_list[[title_var]] <- ydt[, sprintf(
      "%s = %s(%s)",title_var,get(title_var),years)]
  }
  join_meta <- surveys_meta[year_var]
  survey_dt <- join_meta[
  , fread(out.csv,select=variable)[, value := as.character(get(variable))]
  , by=year]
  var_define_dt <- names_list$define[year_var]
  decode_dt <- var_define_dt[
    survey_dt, on=.(year,value)
  ][, response := sprintf("%s(%s)", desc, value)]
  levels_dt <- years_by(
    decode_dt, c("value","response")
  )[order(value,years)]
  levs <- levels_dt$response
  count_dt <- decode_dt[
  , .(count=.N), by=.(year,Response=factor(response,levs))
  ][, prop := count/sum(count), by=year]
  title_items <- unlist(title_list)
  gg <- ggplot()+
    ggtitle(paste(title_items, collapse=",\n"))+
    geom_tile(aes(
      year, Response, fill=log10(prop)),
      data=count_dt)+
    scale_fill_gradient(low="white", high="red")+
    geom_text(aes(
      year, Response, label=sprintf("%.1f", prop*100)),
      data=count_dt)+
    scale_x_continuous(breaks=unique(count_dt$year))
  out.png <- sprintf(
    "figure-heatmap-response-prop-over-years-%s.png",
    vname)
  print(out.png)
  vertical.items <- length(c(levs,title_items))
  png(out.png,width=6+max(nchar(levs))*0.05,height=1+vertical.items*0.2,units="in",res=200)
  print(gg)
  dev.off()
}

