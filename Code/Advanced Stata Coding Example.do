*	 																		   *
*						   	     Jasmine Adams								   *
*					      	  PPOL 768 -- Week 05 						       *
*						   Updated: February 24, 2023						   *
*							      05-wk-ja.do								   *
*																			   *
* 							   - Program Setup -							   *

	version 17             	    // Version no. for backward compatibility
	set more off                // Disable partitioned output
	set linesize 120            // Line size limit for readability
	clear all                   // Start with a clean slate
	* macro drop _all           // Clear all macros
	* capture log close         // Close existing log files
	
* Datasets may be downloaded here: 
* github.com/gui2de/ppol768-spring23/tree/main/Class%20Materials/week-05/02_data
	
	global main    "/Users/jasmineadams/Dropbox/R Stata"
	global rd      "$main/repositories/Rsrch-Dsgn"
	global wd5	   "$rd/w05-ja"
	global w5q1    "$wd5/q1_psle_student_raw.dta"	
	global w5q2e   "$wd5/q2_CIV_populationdensity.xlsx"
	global w5q2    "$wd5/q2_CIV_Section_0.dta"	
	global w5q3    "$wd5/q3_GPS Data.dta"	
	global w5q4e   "$wd5/q4_Tz_election_2010_raw.xlsx"
	global w5q4    "$wd5/q4_Tz_election_template.dta"
	global w5q510  "$wd5/q5_Tz_elec_10_clean.dta"
	global w5q515  "$wd5/q5_Tz_elec_15_clean.dta"
	cd 			   "$wd5"
	
* ---------------------------------------------------------------------------- *
* ---------------------------------------------------------------------------- *

*				       -- Q1 : Tanzania Student Data -- 

* This builds on Q4 of week 4 assignment. We downloaded the PSLE data of 
* students of 138 schools in Arusha District in Tanzania (previously had data 
* of only 1 school). You can build on your code from week 4 assignment to create 
* a student level dataset for these 138 schools.


						   ***  --APPENDING DATA--  *** 
	clear
	
	tempfile  q1temp   
	save	 `q1temp', replace emptyok
	
	qui forvalues i = 1/138 {
		display	  as error `i'
		use       "$w5q1", clear  
		replace   schoolcode = substr(schoolcode,7,7)
		destring  (schoolcode), replace
		format    %07.0f schoolcode
		sort      schoolcode
		gen       snum = _n
		order     snum, first
		keep      in `i'
		split     s, parse(">PS")
		gen       id = _n
		order     id, first
		drop      s
		reshape   long s, i(id) j(student)
		split     s, parse("<")
		keep      snum schoolcode s1 s6 s11 s16 s21
		drop      in 1
		rename    (s1 s6 s11 s16 s21) (cand_id prem_number sex names subjects)
		compress
		gen       cnum = _n
		format    %04.0f cnum
		append    using `q1temp' 
		save     `q1temp', replace
	}
							***  --DATA CLEANING--  *** 
							
	use      `q1temp',    clear	
	sort      snum cnum	
	order     cnum,       first
	order     schoolcode, first
	order     snum,       first
	local     vari        cand_id prem_number sex names subjects
	foreach   x in        `vari'  {
		replace `x'     = subinstr(`x',     `"""',              "", .)
	}
	replace   names     = subinstr(names,    "P>",              "", .)
	replace   subjects  = subinstr(subjects, "P ALIGN=LEFT>",   "", .)
	replace   prem      = subinstr(prem,     "P ALIGN=CENTER>", "", .)
	replace   sex       = subinstr(sex,      "P ALIGN=CENTER>", "", .)
	replace   cand_id   =                    "PS" + cand_id
	destring  prem,       replace 
	format    %11.0f      prem	
	encode    sex,        gen(gender)
	gen       kiswahili = substr(subjects,13,1)
	gen       english   = substr(subjects,26,1)
	gen       maarifa   = substr(subjects,39,1)
	gen       hisabati  = substr(subjects,53,1)
	gen    	  science   = substr(subjects,66,1)
	gen   	  uraia     = substr(subjects,77,1)
	gen       average   = substr(subjects,-1,1)
	encode    kiswahili,  gen(Kiswahili)
	encode    english,    gen(English)
	encode    maarifa,    gen(Maarifa)
	encode    hisabati,   gen(Hisabati)
	encode    science,    gen(Science)
	encode    uraia,      gen(Uraia)
	encode    average,    gen(Average)
	drop      subjects    kiswahili english maarifa ///
				 		  hisabati science uraia average
	

*				    -- Q2 : Côte d'Ivoire Population Density -- 
	
* We have household survey data and population density data for Côte d'Ivoire. 
* Merge departmente-level density data from the excel sheet 
* (CIV_populationdensity.xlsx) into the household data (CIV_Section_O.dta) 
* i.e. add population density column to the CIV_Section_0 dataset.
	
	clear 
	
	tempfile  q2temp   
	save	 `q2temp',         replace emptyok
	import    excel "$w5q2e",  sheet("Population density") ///
							   firstrow case(lower) clear
	keep if                    regex( nomcirconscription, "DEPARTEMENT") == 1
	gen       departmen1     = substr(nomcirconscription, 16, .)
	gen       departmen2     = lower(departmen1)
	encode    departmen2,	   gen(department)
	drop      departmen1	   departmen2 nomcirconscription 
	order 	  department,      first
	sort      department
	append    using           `q2temp' 
	save     `q2temp',         replace
	use       "$w5q2",         clear
	rename    b06_departemen   department
	merge     m:1 department   using `q2temp'
	drop      in 12900

*				    -- Q3 : Côte d'Ivoire Population Density -- 

* We have the GPS coordinates for 111 households from a village. Your job is to 
* assign these households to 19 enumerators (~6 surveys per enumerator per day) 
* such that each enumerator is assigned 6 households that are near each other. 
* Write an algorithm that would auto assign each household (i.e. add a column 
* and assign it a value 1-19 which can be used as enumerator ID). Note: Your 
* code should still work if I run it on data from another village.	

	clear 

	use      	 "$w5q3", clear 
	gen		      enum =  0
	save         "$w5q3", replace
	
	qui forvalues i = 1/16 {
		use      	 "$w5q3", clear
		drop if		 enum != 0
		sort 		 latitude longitude
		rename 		 * *1 
		keep         latitude1 longitude1
		keep		 in 1
		cross 		 using "$w5q3" 
		geodist      latitude1 longitude1 latitude longitude, gen(d`i')
		sort 		 enum d`i'
		gen 		 row  = _n
		replace      enum = `i' if row < 7
		drop         row latitude1 longitude1 d`i'
		save         "$w5q3", replace
		}
		
	qui forvalues i = 17/19 {			// Making the last 3 groups of 5 since 
		use      	 "$w5q3", clear	    // 111 is not divisible by 6
		drop if		 enum != 0
		sort 		 latitude longitude
		rename 		 * *1 
		keep         latitude1 longitude1
		keep		 in 1
		cross 		 using "$w5q3" 
		geodist      latitude1 longitude1 latitude longitude, gen(d`i')
		sort 		 enum d`i'
		gen 		 row = _n
		replace      enum = `i' if row < 6
		drop         row latitude1 longitude1 d`i'
		save         "$w5q3", replace
		}
	
		sort enum
		
		use          "$w5q3", clear
		drop		  enum
		save         "$w5q3", replace
	
*				    -- Q4 : Tanzania Election Data cleaning --

* 2010 election data (Tz_election_2010_raw.xlsx) from Tanzania is not usable in 
* its current form. You have to create a dataset in the wide form, where each 
* row is a unique ward and votes received by each party are given in separate 
* columns. You can check the following dta file as a template for your output: 
* Tz_elec_template. Your objective is to clean the dataset in such a way that 
* it resembles the format of the template dataset.
	
	import excel "$w5q4e", sheet("Sheet1") cellrange(A5:J7927) ///
	firstrow case(lower) clear

	drop         	in 1 
	drop      		electedcandidate 	g sex
	rename       	costituency    		constit
	rename 			politicalparty 		party
	carryforward 	region,        		replace
	carryforward 	district,      		replace
	carryforward 	constit,	  		replace
	carryforward 	ward,          		replace
	
	local areas 	region district 	constit ward candidatename party
	foreach      x  in `areas' {
		replace `x' = strrtrim(`x')
		replace `x' = subinstr(`x',"   "," ",.)
		replace `x' = subinstr(`x',"  "," ",.)
	}
	
	replace         party             = "ApptMaendeleo" if party == ///
										"APPT - MAENDELEO"
	replace         party             = "JahaziAsilia" if party == /// 
									    "JAHAZI ASILIA"
	replace         party             = "NccrMageuzi" if party == /// 
									    "NCCR-MAGEUZI"
	replace      	ttlvotes          = "0" if ttlvotes == "UN OPPOSSED"
	destring     	ttlvotes,      		replace
	
	generate		num 			  = 1
	bysort ward:    egen          		tcands10  = total(num)
	bysort ward:    egen          		tvoters10 = total(ttlvotes)
	bysort war par: egen         		pvotes10  = total(ttlvotes)
	encode 			party,				gen(party10)
	encode 			ward,         		gen(ward10)
	encode 			region,       		gen(region10)
	encode 			district,     		gen(district10)
	encode 			constit		, 		gen(constit10)
	sort    		ward region 		district 
	gen 			id 				  = (ward10 * 100000) + ///
										(region10 * 1000) + district10
	format 		    %9.0f id   
	order 			id, first
	drop 			region district 	constit ttl ward cand num party10
	duplicates 		drop id party, 		force
	reshape	wide 	pvotes10, 			i(id) j(party) string
	
	order 			tcands10,	first
	order 			tvoters10, 	first
	order 			ward10, 	first
	order 			constit10,  first  
	order 			district10, first  
	order 			region10, 	first 
	order 			id, 		first   
	rename  		pvotes10* 	*10
	rename  		id 			election10
	rename  		CHADEMA		Chadema10
	rename  		CHAUSTA 	Chausta10
	rename  		MAKIN   	Makin10
	rename  		TADEA   	Tadea10
	label 			variable 	election10 	"Election ID"
	label 			variable 	tvoters10 	"Voters per ward"
	label 			variable 	tcands10 	"Candidates per ward"
	label			variable 	region10 	"Region"
	label			variable 	district10 	"District"
	label 			variable 	constit10 	"Constituency"
	label 			variable 	ward10 		"Ward"
	sort 			region10 	district10 ward10
	gen 			id = _n
	order			id, first

	
	

*______________________________________________________________________________*
*																			   *	
*	 																		   *
*						   	     Jasmine Adams								   *
*					      	  PPOL 768 -- Week 09 						       *
*						      Updated: April 2023						       *
*							        09-wk.do								   *
*																			   *
* 							   - Program Setup -							   *


   global main 		"/Users/jasmineadams/Dropbox/R Stata"
   global myrepo   	"$main/repositories/Rsrch-Dsgn"
   global classrepo	"$main/repositories/ppol768-spring23"
   global w9 "$classrepo/Individual Assignments/Adams Jasmine/week-09/outputs"
   cd 				"$w9"
/*______________________________________________________________________________

Part 1: Develop some data generating process with:
	- random noise 
	- strata groups of different sizes 
	- strata groups that affect Y 
	- strata groups that affect P(treat = 1) 
   Specifically:
	- x1 that affects Y
	- x2 that affects P(treat = 1) 
	- x3 that affects Y and P(treat = 1) 

	How do x1, x2, and x3 (confounder) bias results?

	- Run 5 regressions with fixed effects 
	- Simulate different sample sizes 
	- Compare bias and convergence as N increases 
	- Display beta mean vs. variance for models as N increases 
		- Include the "true" parameter value
*/
clear		
capture program drop cscore		
program define cscore, rclass		          // define the program
args    obs effect		     			      // require sample size
clear
									        
set 	obs 5 					 			  // gen strata (grad schools)
gen     r1 = runiform()					      // values between 0 & 1
sort 	r1									  // order rows low to high
gen     pct = r1[_n+1]-r1  					  // pct = interval bw rows
replace pct = 1-r1 if pct == .				  // incl. interval bw last row & 1 
set 	obs 6								  // add 6th strata group
replace pct = r1[1] if pct == . 			  // incl. interval bw 0 & 1st row 
replace pct = (.9/6) + .1*(pct)			      // sum of varied strata = 1
gen 	ssize = pct*`obs'               	  // vary obs per school

gen     school = _n							  // school variable
gen 	e1 = rnormal(1.5)  			          // school effects on Y
gen 	t1 = school+runiform(-2,2)			  // school effects on treated = 1    
		
expand  ssize								  // gen obs
bysort  school: gen schoolid = _n 		      // student id by school
gen 	id = _n								  // obs id 
gen     e2 = rnormal(0,2) 	      			  // student effects on Y 
				     
gen 	age = int(rnormal(25,3))              // age  
replace age = age+runiformint(5,10) if age<20 // (min = 20); right skew 
xtile 	xage = age, nquantiles(6)   	 	  // 		  	
gen  	t2 = xage+runiform(-1,1)              // age effects on treated = 1 
											  
gen 	limit = rnormal(20000,3500)           // credit limit (mean centered)
gen     invlim = -1*limit 					  // 
xtile 	xlimit = invlim, nquantiles(6)   	  // assign higher # to low values	
gen 	t3 = xlimit+runiform(1,2)             // limit effects on treated = 1

gen     parcredit = int(rnormal(750,35))      // parents credit 

egen 	rank = rank(t1 + t2 + t3)		      // rank treated = 1 effects
gen 	treatment = rank >= _N/2			  // assign treatment 50/50 
		        
		*-----------------||  DGP for credit score (Y) ||----------------*	
		gen y = 0          ///				       	 y | dependent 
		+ 7.6*age   	   ///                     age | positive 
		+ .67*par   	   ///               parcredit | positive  
		+ 9.5*e1           ///			   	    school | noise
		+ 9.5*e2           ///		 		   student | noise
		+ `effect'*(treat*rnormal(1,.5))      // treat | positive +noise 		
		replace y = round(y, 1)
		*----------------------------------------------------------------*

xtset, 	clear						 		  // set strata for fe
xtset 	school

xtreg 	y treatment, rob fe   				  // reg 1 
matrix 	a = r(table)				     		  
return 	scalar obs = `obs'
return 	scalar b0 = a[1,1]
return 	scalar p0 = a[4,1]

xtreg 	y treat age limit parcredit, rob fe   // reg 2 
matrix 	a = r(table)				     		  
return 	scalar b1 = a[1,1]
return 	scalar p1 = a[4,1]
                                  
xtreg 	y treat age, rob fe			 		  // reg 3 
matrix 	a = r(table)				
return 	scalar age = a[1,1]

xtreg 	y treat limit, rob fe		 		  // reg 4 
matrix 	a = r(table)				 
return 	scalar limit = a[1,1]

xtreg 	y treat parcredit, rob fe    		  // reg 5 
matrix 	a = r(table)				
return 	scalar parcredit = a[1,1]

end                       

				*---------*--SIMULATE--*---------*					     
clear
tempfile tp1	                              // tempfile
save `tp1', replace emptyok 		   
forvalues i=4/7{						      // simulate loop
	local N = round(3^`i',10)			      // indicate sample sizes
	tempfile sim						   
	simulate size=r(obs) b0=r(b0) b1=r(b1)    ///
			 age=r(age) limit=r(limit) 		  ///
			 parcredit=r(parcredit), 		  ///    
			 reps(500) seed(135791)           ///
			 saving(`sim'): cscore `N' 25     	
	use `sim', clear
	append using `tp1'                        // save stats in combined file
	save `tp1', replace                		  
	}	
use 	`tp1', clear
replace size = round(size, 10)
xtile 	csize = size, nquantiles(4)
label 	define csize 1 "80" 2 "240" 3 "730" 4 "2190"
label 	values csize csize
save 	"$w9/part1.dta", replace	


use 	"part1.dta", clear 			   		  
tabstat b0 age limit parcredit b1 
scatter b0 b1 csize, ///
		mcolor(erose%10 sienna%10) ///
		ytitle("Betas") ///
		xtitle("Sample Size") ///
		legend(pos(5) ///
		ring(0) ///
		lab(1 "No controls") ///
		lab(2 "Controls")) ///
		xlabel(, valuelabel)
graph	save "$w9/graphp1.gph", replace

 
 
/* Part 2: Biasing a parameter estimate using controls-------------------------
	- x4 that affects Y as a f(treatment); (exc. treatment)
	- x5 that affects Y and P(treat = 1)
*/

clear		
capture program drop cscore2		
program define cscore2, rclass		          // define the program
args    obs effect		     			      // require sample size
clear
									        
set 	obs 5 					 			  // gen strata (grad schools) 
gen     r1 = runiform()					      // values between 0 & 1
sort 	r1									  // order rows low to high
gen     pct = r1[_n+1]-r1  					  // pct = interval bw rows
replace pct = 1-r1 if pct == .				  // incl. interval bw last row & 1 
set 	obs 6								  // add 6th strata group
replace pct = r1[1] if pct == . 			  // incl. interval bw 0 & 1st row 
replace pct = (.9/6) + .1*(pct)			      // sum of varied strata = 1
gen 	ssize = pct*`obs'               	  // vary obs per school

gen     school = _n							  // school variable
gen 	e1 = rnormal(1.5)  			          // school effects on Y
gen 	t1 = school+runiform(-2,2)			  // school effects on treated = 1    
		
expand  ssize								  // gen obs
bysort  school: gen schoolid = _n 		      // student id by school
gen 	id = _n								  // obs id 
gen     e2 = rnormal(0,2) 	      			  // student effects on Y 
				     
gen 	age = int(rnormal(25,3))              // age  
replace age = age+runiformint(5,10) if age<20 // (min = 20); right skew 
xtile 	xage = age, nquantiles(6)   	 	  // 		  	
gen  	t2 = xage+runiform(-1,1)              // age effects on treated = 1 
											  
gen 	limit = rnormal(20000,3500)           // credit limit (mean centered)
gen     invlim = -1*limit 					  // 
xtile 	xlimit = invlim, nquantiles(6)   	  // assign higher # to low values	
gen 	t3 = xlimit+runiform(1,2)  			  // limit effects on treated = 1

gen     parcredit = int(rnormal(750,35))      // parents credit 

gen 	female = runiformint(0,1)			  // gender (collider)
gen 	t4 = 2*female					      // gender effects on treated = 1

egen 	rank = rank(t1 + t2 + t3 + t4)		  // rank treated = 1 effects
gen 	treatment = rank >= _N/2			  // assign treatment 50/50 

gen 	u1 = runiformint(1,3)                 // treatment on treatment
gen 	ttreatment = treatment				  
replace ttreat = 0 if treat == 1 & u1 == 1 
		        
		*-----------------||  DGP for credit score (Y) ||----------------*	
		gen y = 0          ///				       	 y | dependent 
		+ 7.6*age   	   ///                     age | positive 
		+ .67*par   	   ///               parcredit | positive  
		+ 9.5*e1           ///			   	    school | noise
		+ 9.5*e2           ///		 		   student | noise
		+ -20*female       ///					female | negative
		+ (`effect'*1.5)*(tt*rnormal(1,.5))   // treat | positive +noise 		
		replace y = round(y, 1)
		*----------------------------------------------------------------*

xtset, 	clear						 		  // set strata for fe
xtset 	school

xtreg 	y treatment, rob fe   				  // reg 1 
matrix 	a = r(table)				     		  
return 	scalar obs = `obs'
return 	scalar b0 = a[1,1]
return 	scalar p0 = a[4,1]

xtreg 	y trea fem ag lim parcr, rob fe   	  // reg 2 
matrix 	a = r(table)				     		  
return 	scalar b1 = a[1,1]
return 	scalar p1 = a[4,1]

xtreg 	y trea tt fem ag lim parcr, rob fe    // reg 3 
matrix 	a = r(table)				     		  
return 	scalar b1tt = a[1,1]

xtreg 	y treat ttreat, rob fe    		   	  // reg 4 
matrix 	a = r(table)				
return 	scalar ttreat = a[1,1]

xtreg 	y treat female, rob fe    		      // reg 5 
matrix 	a = r(table)				
return 	scalar female = a[1,1]
                                  
xtreg 	y treat age, rob fe			 		  // reg 6 
matrix 	a = r(table)				
return 	scalar age = a[1,1]

xtreg 	y treat limit, rob fe		 		  // reg 7 
matrix 	a = r(table)				 
return 	scalar limit = a[1,1]

xtreg 	y treat parcredit, rob fe    		  // reg 8 
matrix 	a = r(table)				
return 	scalar parcredit = a[1,1]

end   			
	
				*---------*--SIMULATE--*---------*					     
clear
tempfile tp2	                              // tempfile
save `tp2', replace emptyok 		   
forvalues i=4/7{						      // simulate loop
	local N = round(3^`i',10)			      // indicate sample sizes
	tempfile sim						   
	simulate size=r(obs) b0=r(b0) b1=r(b1)    ///
			 b1tt=r(b1tt) ttreat=r(ttreat)    ///
			 female=r(female) age=r(age) 	  ///
			 limit=r(limit) 		 		  ///
			 parcredit=r(parcredit), 		  ///    
			 reps(500) seed(135792)           ///
			 saving(`sim'): cscore2 `N' 25     	
	use `sim', clear
	append using `tp2'                        // save stats in combined file
	save `tp2', replace                		  
	}	
use 	`tp2', clear
replace size = round(size, 10)
xtile 	csize = size, nquantiles(4)
label 	define csize 1 "80" 2 "240" 3 "730" 4 "2190"
label 	values csize csize
save 	"$w9/part2.dta", replace	


use 	"part2.dta", clear 			   		  
tabstat b0 age limit parcredit female ttreat
tabstat b0 b1 b1tt
scatter b0 b1 csize, ///
		mcolor("168 135 36%12" "115 128 77%12") ///
		ytitle("Betas") ///
		xtitle("Sample Size") ///
		legend(pos(5) ///
		ring(0) ///
		lab(1 "No controls") ///
		lab(2 "Controls")) ///
		xlabel(, valuelabel)
graph	save "$w9/graphp2.gph", replace	   		  
		
