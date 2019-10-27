%let path = C:/Users/Jackson Cabell/Documents/Homework/Time Series/Final Project;
libname ts "&path";

* Aggregate all datasets so variables are monthly averages;

*MonthlyPM;
proc import datafile = "&path/PM_2_5_Raleigh2.csv" dbms = csv
	out = timeseries replace;
run;

proc means data=timeseries mean;
	class date;
	var DailyMeanPM;
	format date monyy7.;
	output out=timeseries mean=MonthlyPM;
run;

data timeseries;
	set timeseries;
	if _Type_ = 0 then delete;
	drop _Type_;
	month = month(date);
	index=_N_-1;
	index_2 = index**2;
run;

*MonthlyCO;
proc import datafile = "&path/CO_Raleigh.csv" dbms = csv
	out = co replace;
run;

proc means data=co mean;
	class date;
	var DailyCO;
	format date monyy7.;
	output out=co mean=MonthlyCO;
run;


data co;
	set co;
	if _Type_ = 0 then delete;
	drop _Type_;
	drop _FREQ_;
	index=_N_-1;
run;

*MonthlyNO2;
proc import datafile = "&path/NO2_Raleigh.csv" dbms = csv
	out = no2 replace;
run;

proc means data=no2 mean;
	class date;
	var DailyNO2;
	format date monyy7.;
	output out=no2 mean=MonthlyNO2;
run;


data no2;
	set no2;
	if _Type_ = 0 then delete;
	drop _Type_;
	drop _FREQ_;
	index=_N_-1;
run;

*MonthlySO2;
proc import datafile = "&path/SO2_Raleigh.csv" dbms = csv
	out = so2 replace;
run;

proc means data=so2 mean;
	class date;
	var DailySO2;
	format date monyy7.;
	output out=so2 mean=MonthlySO2;
run;


data so2;
	set so2;
	if _Type_ = 0 then delete;
	drop _Type_;
	drop _FREQ_;
	index=_N_-1;
run;

*Monthly Weather vars;
proc import datafile = "&path/Weatherdata.csv" dbms = csv
	out = weather replace;
run;

****** Fill in missing values of WT01 with 0;
data weather;
	set weather;
	if missing(WT01) then WT01 = 0;
run;

proc means data=weather mean;
	class date;
	var AWND PRCP SNOW SNWD TAVG TMAX TMIN WSF2 WSF5 WT01;
	format date monyy7.;
	output out=weather mean=MonthlyAWND MonthlyPRCP MonthlySNOW MonthlySNWD MonthlyTAVG MonthlyTMAX MonthlyTMIN MonthlyWSF2 MonthlyWSF5 MonthlyWT01;
run;


data weather;
	set weather;
	if _Type_ = 0 then delete;
	drop _Type_;
	drop _FREQ_;
	index=_N_-1;
run;

********* Keep the first 60 months for training/validation from weather;
data weather60 ts.weather2019;
	set weather;
	if _N_ <=60 then output weather60;
	else output ts.weather2019;
run;



*Merge all of the data on date;
proc sql;
CREATE TABLE ts.fulldata AS
SELECT timeseries.Date,
		month,
		timeseries.index,
		index_2,
		MonthlyPM,
		MonthlyCO,
		MonthlyNO2,
		MonthlySO2,
		MonthlyAWND,
		MonthlyPRCP,
		MonthlySNOW,
		MonthlySNWD,
		MonthlyTAVG,
		MonthlyTMAX,
		MonthlyTMIN,
		MonthlyWSF2,
		MonthlyWSF5,
		MonthlyWT01	
FROM timeseries
	LEFT JOIN
	co on timeseries.index=co.index
	LEFT JOIN
	no2 on timeseries.index=no2.index
	LEFT JOIN
	so2 on timeseries.index=so2.index
	LEFT JOIN
	weather on timeseries.index=weather.index;
quit;

*Create ramp variable;
data ts.fulldata;	
set ts.fulldata;
if index < 39 then ramp = 0;
if index = 39 then ramp = 1;
if index = 40 then ramp = 2;
if index = 41 then ramp = 3;
if index = 42 then ramp = 4;
if index = 43 then ramp = 5;
if index = 44 then ramp = 6;
if index = 45 then ramp = 7;
if index = 46 then ramp = 8;
if index = 47 then ramp = 9;
if index = 48 then ramp = 10;
if index = 49 then ramp = 11;
if index = 50 then ramp = 12;
if index = 51 then ramp = 13;
if index = 52 then ramp = 14;
if index = 53 then ramp = 15;
if index = 54 then ramp = 16;
if index = 55 then ramp = 17;
if index = 56 then ramp = 18;
if index = 57 then ramp = 19;
if index = 58 then ramp = 20;
if index = 59 then ramp = 21;
if index = 60 then ramp = 22;
run;

*Export data as csv;
proc export data=ts.fulldata outfile = "&path/fulldata.csv" dbms = csv
replace;

*Create training (with blanks for validation) and validation;

data ts.training;
	set ts.fulldata;
	if _N_ >= 55 then do;
		MonthlyPM = .;
		MonthlyCO = .;
		MonthlyNO2 = .;
		MonthlySO2 = .;
		MonthlyAWND = .;
		MonthlyPRCP = .;
		MonthlySNOW = .;
		MonthlySNWD = .;
		MonthlyTAVG = .;
		MonthlyTMAX = .;
		MonthlyTMIN = .;
		MonthlyWSF2 = .;
		MonthlyWSF5 = .;
		MonthlyWT01	 = .;
	end;
run;

data ts.validation;
	set ts.fulldata;
	if _N_ >= 55;
run;
	

