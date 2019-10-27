%let path = C:/Users/Jackson Cabell/Documents/Homework/Time Series/Final Project;
libname ts "&path";

/********************************** Creating best ARIMAX model *******************/

/* Visualize the data!!!!  */
proc sgplot data=ts.training;
series x=index y=MonthlyPM;
run;
quit;

proc sgplot data=ts.training;
series x=index y=MonthlyCO;
run;
quit;
*Repeat for every x and save image of plot;

*Check out all xvars with MonthlyPM via proc glmselect to see which will be significant;
proc glmselect data=ts.training;
model MonthlyPM= MonthlyCO MonthlyNO2 MonthlySO2 MonthlyAWND MonthlyPRCP
				MonthlySNOW MonthlySNWD MonthlyTAVG MonthlyTMAX MonthlyTMIN
				MonthlyWSF2 MonthlyWSF5 MonthlyWT01 /selection=backward select=BIC;
run;
quit;

*Visualize Co, SO2, and TAVG against PM;
proc sgplot data=ts.training;
series x=index y=MonthlyPM;
series x=index y=MonthlyCO;
series x=index y=MonthlySO2;
series x=index y=MonthlyTAVG;
run;
quit;

********************** Look at each X series individually to get stationarity******;
*CO;
proc arima data = ts.training;
identify var = MonthlyCO stationarity=(adf=2);
run;
quit;

*SO2;
proc arima data = ts.training;
identify var = MonthlySO2(1) stationarity=(adf=2);
run;
quit;

*TAVG;
proc arima data = ts.training;
identify var = MonthlyTAVG(1) stationarity=(adf=2);
run;
quit;

*Fit the x variables and see if there's any signal left by examining the residuals;
proc arima data=ts.training;
identify var = MonthlyPM crosscorr = (MonthlyCO MonthlySO2(1) MonthlyTAVG(1) index index_2) nlag=24;
estimate input = (MonthlySO2(1) MonthlyTAVG(1) MonthlyCO index index_2) method = ML;
forecast out=resid1;
run;
quit;

proc arima data=resid1;
identify var=residual stationarity =(adf=2);
quit;

*Residuals are stationary around zero;
proc arima data=resid1 plots = all;
identify var=residual nlag=24;
estimate p = (1)(12) q = 3 method = ML;
ods output residualcorrpanel=corr;
run;
quit;

proc export data=corr outfile="&path/whitenoise_arimax.csv"
	dbms = csv replace;

*Need to predict transfer functions;
*Create monthly dummies for MonthlCO to use because it has monthly seasonality;
/*
data ts.training;
set ts.training;
if month=1 then seas1=1; else seas1=0;
if month=2 then seas2=1; else seas2=0;
if month=3 then seas3=1; else seas3=0;
if month=4 then seas4=1; else seas4=0;
if month=5 then seas5=1; else seas5=0;
if month=6 then seas6=1; else seas6=0;
if month=7 then seas7=1; else seas7=0;
if month=8 then seas8=1; else seas8=0;
if month=9 then seas9=1; else seas9=0;
if month=10 then seas10=1; else seas10=0;
if month=11 then seas11=1; else seas11=0;
run;
*/

*CO;
proc arima data = ts.training plots=all;
identify var = MonthlyCO crosscorr=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8
									seas9 seas10 seas11 index) nlag=24;
estimate input = (seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8
				seas9 seas10 seas11 index) method=ML;
forecast out=coforecast lead=6;
*ods output residualcorrpanel=corr;
run;
quit;

*proc export data=corr outfile="&path/whitenoise_co.csv"
	dbms = csv replace;

*SO2;
proc arima data = ts.training plots=all;
identify var = MonthlySO2(1) nlag = 32;
estimate p=5 q=3 method=ML;
forecast out=soforecast lead=6;
*ods output residualcorrpanel=corr;
run;
quit;

*proc export data=corr outfile="&path/whitenoise_so2.csv"
	dbms = csv replace;

*TAVG;
proc arima data = ts.training plots=all;
identify var = MonthlyTAVG(1) nlag=30;
estimate p=(12) q=4  method=ML;
forecast out=tavgforecast lead=6;
*ods output residualcorrpanel=corr;
run;
quit;

*proc export data=corr outfile="&path/whitenoise_tavg.csv"
	dbms = csv replace;

*Merge all the data together to predict MonthlyPM;
data alltraining;
merge ts.training coforecast(keep=forecast rename = (forecast = copred))
				soforecast(keep=forecast rename=(forecast = sopred))
				tavgforecast(keep=forecast rename=(forecast=tavgpred));
run;

data alltraining;
set alltraining;
if _n_	>= 55 then do;
MonthlyCO = copred;
MonthlySO2 = sopred;
MonthlyTAVG = tavgpred;
end;
run;

*Forecast Monthly PM now;
proc arima data=alltraining;
identify var = MonthlyPM crosscorr = (MonthlyCO MonthlySO2(1) MonthlyTAVG(1) index index_2) nlag=30;
estimate input = (MonthlySO2(1) MonthlyTAVG(1) MonthlyCO index index_2) p = (1)(12) q = 3 method = ML;
forecast lead=6 out=results; 
run;
quit;


*Merge back and calculate MAPE;
*Create index in results;
data results;
	set results;
	index = _n_;
run;

*Merge in validation data;
proc sql;
create table mape as
	select results.forecast, valid.MonthlyPM
	from results
	inner join
	ts.validation as valid
	on results.index=valid.index;
quit;
	

*Calculate MAPE and MAE for validation data (last 6 months);
data mape;
	set mape;
	residual = MonthlyPM-forecast;
	abs_error=abs(residual);
	abs_err_obs=abs_error/abs(MonthlyPM);
run;

*proc export data = mape outfile = "&path/arimaxforecast.csv" dbms=csv replace;

proc means data=mape mean;
var abs_error abs_err_obs;
run;

*************************** Try fitting lags and seeing which are significant ***************;
data ts.training;
	set ts.training;
	co1 = lag1(MonthlyCO);
	co2 = lag2(MonthlyCO);
	co3 = lag3(MonthlyCO);
	co4 = lag4(MonthlyCO);
	co5 = lag5(MonthlyCO);
	so1 = lag1(dif(MonthlySO2));
	so2 = lag2(dif(MonthlySO2));
	so3 = lag3(dif(MonthlySO2));
	so4 = lag4(dif(MonthlySO2));
	so5 = lag5(dif(MonthlySO2));
	temp1 = lag1(dif(MonthlyTAVG));
	temp2 = lag2(dif(MonthlyTAVG));
	temp3 = lag3(dif(MonthlyTAVG));
	temp4 = lag4(dif(MonthlyTAVG));
	temp5 = lag5(dif(MonthlyTAVG));
	diffso = dif(MonthlySO2);
	difftemp = dif(MonthlyTAVG);
run;

proc glmselect data=ts.training;
model MonthlyPM= MonthlyCO co1 co2 co3 co4 co5 diffso so1 so2 so3 so4 so5
				 difftemp temp1 temp2 temp3 temp4 temp5  /selection=backward select=BIC;
run;
quit;

*Try these significant variables in the model to get stationary residuals;
proc arima data=ts.training;
identify var = MonthlyPM crosscorr = (MonthlyCO MonthlyTAVG(1) index index_2) nlag=24;
estimate input = (/(1) MonthlyTAVG (1,2,3) MonthlyCO index index_2) method = ML;
forecast out=resid2;
run;
quit;

proc arima data=resid2 plots=all;
identify var=residual stationarity =(adf=2);
quit;

*Forecast out ;
proc arima data=alltraining plots=all;
identify var = MonthlyPM crosscorr = (MonthlyCO MonthlyTAVG(1) index index_2) nlag=30;
estimate input = (/(1) MonthlyTAVG (1,2,3) MonthlyCO index index_2) p=2 q=2 method = ML;
forecast out=results lead=6;
*ods output residualcorrpanel=corr;
run;
quit;

*proc export data=corr outfile="&path/whitenoise_arimax2.csv"
	dbms = csv replace;

*Merge back and calculate MAPE;
*Create index in results;
data results;
	set results;
	index = _n_;
run;

*Merge in validation data;
proc sql;
create table mape as
	select results.forecast, valid.MonthlyPM
	from results
	inner join
	ts.validation as valid
	on results.index=valid.index;
quit;
	

*Calculate MAPE and MAE for validation data (last 6 months);
data mape;
	set mape;
	residual = MonthlyPM-forecast;
	abs_error=abs(residual);
	abs_err_obs=abs_error/abs(MonthlyPM);
run;

*proc export data = mape outfile = "&path/arimaxforecast2.csv" dbms=csv replace;

proc means data=mape mean;
var abs_error abs_err_obs;
run;
	









