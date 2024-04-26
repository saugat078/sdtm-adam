/*******************************************************************************************************
Program Name:                 cm.sas
Project:                      NIM-55-22
Purpose:                      Create SDTM Dataset of cm
Original Author:              Saugat Poudel
Date Created:                 04/02/2024
Parameters:                   NA
Input:                        [raw.cm](http://raw.cm/),
Output:                       [out.dm](http://out.dm/)
External macro referenced:    None
Modifications:
Date        By             Changes
---
04/02/2024   Saugat				Made changes on codes

- *******************************************************************************************************/
/* 1 */

data out.renam;
	length DOMAIN $6;
	length CMSTDTC $10;
    length CMENDTC $10;
	label DOMAIN="Domain Abbreviation";
    set raw.cm (rename=(datapagename=CMCAT));
    label CMSTDTC='Start Date/Time of Medication';
    label CMENDTC='End Date/Time of Medication';
    label CMCAT="Category for Medication";
    label CMTRT="Reported Name of Drug, Med, or Therapy";
    label CMROUTE="Route of Administration";
    label CMDOSE="Dose per Administration";
    DOMAIN="CM";
    CMSTDTC = substr(compress(CMSTDT_RAW), 1, 9);
	CMENDTC = substr(compress(CMENDT_RAW), 1, 9);
    if substr(CMSTDTC,3,3)="UNK" then do;
        CMSTDTC=substr(CMSTDTC,6,4);
    end;
    if substr(CMENDTC,3,3)="UNK" then do;
        CMENDTC=substr(CMENDTC,6,4);
    end;
    if substr(CMSTDTC,1,2)="UN" then do;
        year=substr(CMSTDTC,6,4);
        month=substr(CMSTDTC,3,3);
        date=input(cats(month,year),monyy7.);
        CMSTDTC=put(date,yymmd.);
    end;
    if substr(CMENDTC, 1,2)="UN" then do;
        year=substr(CMENDTC,6,4);
        month=substr(CMENDTC,3,3);
        date=input(cats(month,year),monyy7.);
        CMENDTC=put(date,yymmd.);
    end;
    else do;
    	std=input(CMSTDTC,date9.);
    	CMSTDTC=put(std,yymmdd10.);
    	ends=input(CMENDTC,date9.);
    	CMENDTC=put(ends,yymmdd10.);
    end;
/*     keep CMSTDTC CMENDTC; */
    drop year month date std ends;
    where cmyn_std ne "2";
run;

/* 2 */
proc sort data=out.renam out=sorted_raw;
	by subject STUDYID cmtrt CMSTDTC;
run;

%let study_id ='NIM-55-22';
data uniques;
	length STUDYID $9;
	length CMDOSFRQ $8;
	length USUBJID $19; 
	set sorted_raw(rename=(cmunit=CMDOSU));
	if cmdosu="Tablet" then cmdosu=upcase(cmdosu);
	if cmfreq_std="X1" then CMDOSFRQ="ONCE";
	else CMDOSFRQ=cmfreq_std;
	label CMDOSFRQ="Dosing Frequency per Interval";
	STUDYID=&study_id;
	label STUDYID="Study Identifier";
	USUBJID=catx('-',&study_id,subject);
	label USUBJID='Unique Subject Identifier';
	by subject STUDYID cmtrt CMSTDTC;
	retain CMSEQ 0;
	label CMSEQ='Sequence Number';
	if first.subject then CMSEQ=0;
		CMSEQ+1;
	drop cmfreq_std;
/* 	keep USUBJID CMSEQ CMSTDTC CMENDTC; */
run;

/* 3 */ 
data study;
	merge uniques(in=a) sdtm.dm(in=b);
	if a and b;
	by USUBJID;
    sdate=input(CMSTDTC,yymmdd10.);
	edate=input(CMENDTC,yymmdd10.);
	rfstdt=input(substr(rfstdtc,1,10),yymmdd10.);
	if sdate<rfstdt then do;
		CMSTDY=sdate-rfstdt;
	end;
	else do;
		CMSTDY=(sdate-rfstdt)+1;
	end;
	if edate<rfstdt then do;
		CMENDY=edate-rfstdt;
	end;
	else do;
		CMENDY=(edate-rfstdt)+1;
	end;
	drop armcd sdate edate rfstdt ;
	label CMSTDY='Study Day of Start of Medication'
		 CMENDY='Study Day of End of Medication';
/* 	keep project projectid subject CMSTDTC CMENDTC CMSTDY CMENDY CMSEQ USUBJID rfstdtc; */
run;

data out.final_cm replace;
	set study;
	date_value = scan(CMENDTC,1);
	if missing(date_value) then do;
	CMENRF="ONGOING";
	CMENDTC="";
	end;
	label CMENRF="End Relative to Reference Period";
	CMROUTE=upcase(CMROUTE);
	keep STUDYID CMCAT domain USUBJID CMSEQ cmtrt cmdose cmdosu CMDOSFRQ cmroute CMSTDTC CMENDTC CMSTDY CMENDY CMENRF;
run;


proc sort data=sdtm.cm_validate out=a;
	by USUBJID CMSEQ;
run;
proc print data=out.final_cm;
run;
proc print data=a;
run;

proc compare base=out.final_cm compare=a;
run;




	

