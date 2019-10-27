%let path = C:/Users/Jackson Cabell/Documents/Homework/Time Series/HW 4;
libname ts "&path";

proc import datafile = "&path/PM_2_5_Raleigh2.csv" dbms = csv
	out = timeseries replace;
run;

*************************************************************************;
* Aggregate the dataset to be monthly averages;
*************************************************************************;
proc means data=timeseries mean;
	class date;
	var DailyMeanPM;
	format date monyy7.;
	output out=timeseries mean=MonthlyPM;
run;

*************************************************************************;
* Delete the extra row sas creates and drop the type row;
*************************************************************************;
data timeseries;
	set timeseries;
	if _Type_ = 0 then delete;
	drop _Type_;
	month = month(date);
	index=_N_;
	index_2 = index**2;
run;

*************************************************************************;
* Create stl classical decomposition
*************************************************************************;
proc timeseries data=timeseries plots=(series decomp sc) seasonality=12;
	var MonthlyPM;
run;

*************************************************************************;
* Handling Seasonality
	Step 1) DF testing to see if seasonal random walk
	
	RESULT: Reject Ho so model seasonality with deterministic
			functions!
*************************************************************************;
proc arima data=timeseries plot=all;
identify var=MonthlyPM stationarity=(adf=2 dlag=12);
run;
quit;

*************************************************************************;
* Handling Seasonality
	Step 2) Try modeling with dummy variables for each month
		- Fit the dummy variables
		- Analyze the residuals for trend
			-Quadratic trend exists
		- Fit quadratic residuals to test for stationarity
			-Stationary around mean 0
		- Fit AR/MA terms to model correlation structure and achieve white noise
			-Modeled with p=(1,2,12) q=1 and white noise achieved for 24 lags
		- Forecast and calculate MAPE
*************************************************************************;
*Create dummy variables;
data timeseries;
set timeseries;
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

*Fit dummy variables to get residuals for trend testing;
proc reg data=timeseries;
model MonthlyPM=seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11;
output out=dummyresids residual=resids;
run;
quit;

*Test residuals for trend and/or stationarity;
proc arima data = dummyresids;
identify var = resids stationarity=(adf=2);
run;
quit;

************* Handling Trend *************************************;
*Previous test had quadratic trend still in residuals, so fit quad trend;
proc reg data=dummyresids;
	model resids = index index_2;
	output out=dummyquadresids residual=quadresids;
run;
quit;

*Test residuals from quadratic trend for stationarity;
proc arima data = dummyquadresids;
identify var = quadresids stationarity=(adf=2);
run;
quit;

*************************Correlation Structures ***************************;
*Residuals are stationary around mean zero- fit AR/MA terms;
proc arima data = dummyquadresids;
identify var = quadresids stationarity=(adf=2) nlag=24;
estimate p=(1,2,12) q=1;
run;
quit;
*The above model fits 2 MA, 1 AR, and 1 Seasonal MA term;
*White noise is achieved- high pvalues for Ljung Box test, normal resids, and mean 0
	with constant variance;


*************** Put it all together and forecast ***************************************;
*** Fit dummy variables, quadratic trend, and 2 MA, 1 AR, and 1 Seasonal MA terms;
*** Forecast out 6 months;
proc arima data=timeseries;
identify var=MonthlyPM crosscorr=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11 index index_2);
estimate p=(1,2,12) q=1 input=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11 index index_2);
forecast back=6 lead=6 out=results1;
run;
quit;

*Calculate MAPE and MAE for validation data (last 6 months);
data results1;
	set results1;
	if _n_ >= 55;
	abs_error=abs(residual);
	abs_err_obs=abs_error/abs(MonthlyPM);
run;

proc means data=results1 mean;
var abs_error abs_err_obs;
run;
*MAPE = 0.1374586 and MAE = 1.1533917;

*************************************************************************;
* Handling Seasonality	
	Step 3) Try modeling with trig functions
		- Fit the trig variables
		- Analyze the residuals for trend
			- Still quadratic trend so let's fit that again
		- Fit quadratic trend residuals to test for stationarity
			- Stationary around 0 mean
		- Fit AR/MA terms to model correlation structure and achieve white noise
			-Modeled with q=(1,12) and white noise achieved for 24 lags
		- Forecast and calculate MAPE
*************************************************************************;
*Create trig variables;
data timeseries;
set timeseries;
pi=constant("pi");
s1=sin(2*pi*1*_n_/12);
c1=cos(2*pi*1*_n_/12);
s2=sin(2*pi*2*_n_/12);
c2=cos(2*pi*2*_n_/12);
s3=sin(2*pi*3*_n_/12);
c3=cos(2*pi*3*_n_/12);
s4=sin(2*pi*4*_n_/12);
c4=cos(2*pi*4*_n_/12);
s5=sin(2*pi*5*_n_/12);
c5=cos(2*pi*5*_n_/12);
run;

*Fit dummy variables to get residuals for trend testing;
proc reg data=timeseries;
model MonthlyPM=s1 c1 s2 c2 s3 c3 s4 c4 s5 c5;
output out=trigresids residual=resids;
run;
quit;

*Test residuals for trend and/or stationarity;
proc arima data = trigresids;
identify var = resids stationarity=(adf=2);
run;
quit;

************* Handling Trend *************************************;
*Previous test had quadratic trend still in residuals, so fit quad trend;
proc reg data=trigresids;
	model resids = index index_2;
	output out=dummytrigresids residual=quadresids;
run;
quit;

*Test residuals from quadratic trend for stationarity;
proc arima data = dummytrigresids;
identify var = quadresids stationarity=(adf=2);
run;
quit;

*************************Correlation Structures ***************************;
*Residuals are stationary around mean zero- fit AR/MA terms;
proc arima data = dummytrigresids;
identify var = quadresids stationarity=(adf=2) nlag=24;
estimate q=(1,12);
run;
quit;
*The above model fits 1 MA and 1 Seasonal MA term;
*White noise is achieved- high pvalues for Ljung Box test, normal resids, and mean 0
	with constant variance;


*************** Put it all together and forecast ***************************************;
*** Fit 5 trig variables, quadratic trend, and 1 MA and 1 Seasonal MA terms;
*** Forecast out 6 months;
proc arima data=timeseries;
identify var=MonthlyPM crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5 index index_2);
estimate q=(1,12) input=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5 index index_2);
forecast back=6 lead=6 out=results2;
run;
quit;

*Calculate MAPE and MAE for validation data (last 6 months);
data results2;
	set results2;
	if _n_ >= 55;
	abs_error=abs(residual);
	abs_err_obs=abs_error/abs(MonthlyPM);
run;

proc means data=results2 mean;
var abs_error abs_err_obs;
run;
*MAPE = 0.1324287 and MAE = 1.0962607;


