libname time 'C:/Users/Jackson Cabell/Documents/Homework/Time Series/HW 3/';
run;

* Import monthly aggregated data created in R from first HW reports;
*proc import datafile = "C:/Users/Jackson Cabell/Documents/Homework/Time Series/HW 3/ts_ag.csv" 
			dbms = csv out = time.ts_ag replace;

	
/* Augmented Dickey-Fuller Testing */
proc arima data=time.ts_ag plot=all;
	identify var= Mon_Avg_Concentration nlag=10 stationarity=(adf=2);
	identify var= Mon_Avg_Concentration(1) nlag=10 stationarity=(adf=2);
run;
quit;

/*Without trend, look at single mean test -> fail to reject (random walk). Then, 
	take first differences, and look at zero mean test -> reject null -> stationary! */

/*However, there looks like there may be a quadratic (or linear trend). Lets
	fit a quadratic trend and test the residuals. */
	
/*Create a time and time_squared variable to fit a quadratic regression*/
data time.ts_ag;
	set time.ts_ag;	
	t = Date;
	t_sq = Date**2;
	t_log = log(t);

*proc export data = time.ts_ag outfile = "C:/Users/Jackson Cabell/Documents/Homework/Time Series/HW 3/ts_cacl.csv" dbms = csv;
	

/* Fit the quadratic model and get residuals as new value -> pattern in resids -> try log */
proc reg data=time.ts_ag;
	model Mon_Avg_Concentration = t t_sq;
	output out = time.ts_mod_quad
			residual=resids_quad;


/* Augmented Dickey-Fuller Testing on quad residuals */
proc arima data=time.ts_mod_quad plot=all;
	identify var= resids_quad nlag=10 stationarity=(adf=2);
run;
quit;

/* Fit the log model and get residuals as new value */
proc reg data=time.ts_ag;
	model Mon_Avg_Concentration = t_log;
	output out = time.ts_mod_log
			residual=resids_log;

/* Augmented Dickey-Fuller Testing on log residuals */
proc arima data=time.ts_mod_log plot=all;
	identify var= resids_log nlag=10 stationarity=(adf=2);
run;
quit;

/* Shows that data is stationary around logarithmic trend -> look at zero mean test*/


/* Now try it on linear trend*/

proc arima data=time.ts_ag plot=all;
identify var=Mon_Avg_Concentration crosscorr=Date stationarity=(adf=2) ;
estimate input=Date;
run;
quit;

/* Fit the linear model and get residuals as new value -> pattern in resids -> try log */
proc reg data=time.ts_ag;
	model Mon_Avg_Concentration = t;
	output out = time.ts_mod_lin
			residual=resids_lin;


/* Augmented Dickey-Fuller Testing on linear residuals */
proc arima data=time.ts_mod_lin plot=all;
	identify var= resids_lin nlag=10 stationarity=(adf=2);
run;
quit;

/*Residuals are stationary around zero for linear trend -> ready to go!*/





	



