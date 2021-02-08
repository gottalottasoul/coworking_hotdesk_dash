library(tidyverse)
library(lubridate)


#load the data extracts
load("~/OneDrive - CBRE, Inc/data/raw_data/ELT_raw_data.RData")
load("~/OneDrive - CBRE, Inc/data/raw_data/transform_data.RData")

start_date<-as_date("2019-08-01")
yesterdays_date<-today()-1

#Build our Cohorts
n_days <- interval(start_date,yesterdays_date)/days(1)
cohort_dates<- enframe(start_date + days(0:n_days)) %>% 
  mutate(cohort_month=floor_date(value,unit="month"),
         end_month=ceiling_date(value,unit="month")-1) %>% 
  #group_by(cohort_month) %>% 
  select(cohort_month,end_month) %>% 
  unique(.) %>% 
  mutate(end_month=as_date(ifelse(end_month>yesterdays_date,yesterdays_date,end_month)))
  





today_date<-today()

contracts_edited<-nexudus_contracts %>% 
  mutate(businessname=coalesce(businessname,'Not Specified'),
         email=tolower(email),
         plan_name=case_when(
           is.na(plan_name) & !is.na(tariffname)~tariffname,
           is.na(plan_name) & tariffprice==0~'Unknown Plan (likely Promo)',
           is.na(plan_name) & tariffprice>0~'Unknown Plan',
           TRUE~plan_name
         )) %>%
  filter(hana_product=='Share', 
         !businessname=='PwcTestSpace',
         !grepl('sprint.*gmail',email,ignore.case = TRUE)) %>%
  group_by(coworkerid,email) %>% 
  summarise(hana_location=max(businessname),
            first_contract=first(plan_name),
            last_contract=last(plan_name),
            contracts=n(),
            zero_priced_contracts=sum(tariffprice==0),
            total_billed=sum(total_billed,na.rm=TRUE),
            total_paid=sum(total_paid,na.rm=TRUE),
            most_recent_plan_price=(last(plan_price)),
            paying_periods=sum(tariffprice>0),
            earliest_start=as_date(min(startdate)),
            latest_start=as_date(max(startdate)),
            latest_cancel = as_date(max(cancellationdate)),
            latest_invoice = as_date(max(invoicedperiod)),
            latest_term= as_date(max(contractterm)),
            membership_length=time_length(interval(ymd(earliest_start),ymd(coalesce(latest_cancel,today_date))),unit="day"),
            join_month=floor_date(earliest_start,unit="month"),
            still_active= case_when(
              latest_cancel>today()~'Yes',
              latest_cancel>latest_start~'No',
              !is.na(latest_cancel)~'No',
              TRUE~'Yes'),
            active= as.integer(last(active)),
            promo=ifelse(grepl('Promo',first_contract,ignore.case = TRUE),'Yes','No'))


hs_sources<-hs_contacts_edited %>% 
  select(contact_email,first_name,last_name, acquisition_source,acquisition_channel,create_date)


feenics_swipes<-feenics_events %>% 
  mutate(occurence_date=as_date(occurred_on)) %>% 
  group_by(member_email) %>% 
  summarise(swipe_days=n_distinct(occurence_date))

member_swipe_days<-feenics_events %>% 
  mutate(occurence_date=as_date(occurred_on)) %>% 
  select(member_email,occurence_date) %>% 
  unique(.) %>% 
  inner_join(contracts_edited,by=c("member_email"="email")) %>% 
  left_join(hs_sources,by=c("member_email"="contact_email")) %>% 
  select(-contracts,-latest_term) %>% 
  mutate(acquisition_channel=ifelse(is.na(acquisition_channel),"Local (inferred)",acquisition_channel),
         acquisition_source=coalesce(acquisition_source,acquisition_channel),
         swipe_day=wday(occurence_date,label=TRUE,week_start=1)) %>% 
  select(coworkerid,hana_location,acquisition_channel,acquisition_source,promo,earliest_start,join_month,swipe_day)
  



share_members_edited<-contracts_edited %>% 
  left_join(hs_sources,by=c("email"="contact_email")) %>% 
  left_join(feenics_swipes,by=c("email"="member_email")) %>% 
  select(-contracts,-latest_term) %>% 
  mutate(acquisition_channel=ifelse(is.na(acquisition_channel),"Local (inferred)",acquisition_channel),
         acquisition_source=coalesce(acquisition_source,acquisition_channel),
         swipe_days=ifelse(is.na(swipe_days),0,swipe_days),
         member_utilization=swipe_days/membership_length) %>% 
  ungroup(.) %>% 
  mutate_if(is.numeric, ~replace(., is.nan(.), 0)) 


save(share_members_edited,member_swipe_days,file="inc/share_data.RData")
