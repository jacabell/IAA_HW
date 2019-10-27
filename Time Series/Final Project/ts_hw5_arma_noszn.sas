%let path = C:/Users/Jackson Cabell/Documents/Homework/Time Series/Final Project;
libname ts "&path";

/********************************** Creating best ARIMA model (without season)*******************/

*Fit intervention first;
proc reg data=ts.training;
	model MonthlyPM = ramp;
	output out=rampresids residual=rampresids;
run;
quit;

*Linear trend first;

*Test series for stationarity around linear trend get p-values from Trend test here;
proc arima data = rampresids;
identify var = rampresids stationarity=(adf=2);
run;
quit;

*Fit linear trend;
proc reg data=ts.training;
	model MonthlyPM = ramp index;
	output out=linresids residual=linresids;
run;
quit;

*Fit linear trend and add AR/MA terms - get white noise plot from here;
proc arima data=linresids plot=all;
identify var=linresids nlag=24;
estimate p=1 q=1 method=ML;
run;
quit;


*Forecast out and calculate MAPE;
proc arima data=ts.training;
identify var=MonthlyPM crosscorr=(ramp index);
estimate p=1 q=1 input=(ramp index) method=ML;
forecast lead=6 out=results;
run;
quit;

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

proc means data=mape mean;
var abs_error abs_err_obs;
run;

************************** Now trying quadratic trend****************************;

*Fit quadtratic trend;
proc reg data=ts.training;
	model MonthlyPM = ramp index index_2;
	output out=quadresids residual=quadresids;
run;
quit;

*Fit linear trend and add AR/MA terms - get p-values from here;
proc arima data=quadresids plot=all;
identify var=quadresids nlag=24 stationarity=(adf=2);
*estimate p=1 q=1 method=ML;
run;
quit;

*Fit AR/MA terms here- get white noise plot from here;
proc arima data=quadresids plot=all;
identify var=quadresids nlag=24;
estimate q=1 method=ML;
*ods output residualcorrpanel=corr;
run;
quit;

*proc export data=corr outfile="&path/whitenoise_arma.csv"
	dbms = csv replace;


*Forecast out and calculate MAPE;
proc arima data=ts.training;
identify var=MonthlyPM crosscorr=(ramp index index_2);
estimate p=1 input=(ramp index index_2) method=ML;
forecast lead=6 out=results;
run;
quit;

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

proc export data = mape outfile = "&path/armaforecast.csv" dbms=csv replace;

proc means data=mape mean;
var abs_error abs_err_obs;
run;


