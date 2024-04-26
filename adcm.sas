/*******************************************************************************************************
Program Name:                 adcm.sas
Project:                      NIM-55-22
Purpose:                      Create ADAM Dataset of cm
Original Author:              Saugat Poudel
Date Created:                 04/08/2024
Parameters:                   NA
Input:                        sdtm.dm,sdtm.suppcm,sdtm.final_cm,sdtm.adcm_adsl
Output:                       adam.final_adcm
External macro referenced:    None
Modifications:
Date        By             Changes
---
04/08/2024   Saugat				Made changes on codes

- *******************************************************************************************************/

proc sort data=sdtm.suppcm out=sorted;
	by usubjid idvarval;
run;

data array_transpose;
	length ATC $31 ATCCD $5 CMDICVER $24;
	set sorted;
	by usubjid idvarval qnam;
	retain atc atccd cmdicver;
	
	array testcd[3] $10 _temporary_ ("ATC" "ATCCD" "CMDICVER");
	array newvars[3] $40 atc atccd cmdicver;
	
	if first.idvarval then call missing(of newvars[*]);
	do i=1 to dim(testcd);
		if qnam=testcd[i] and qval ne "" then newvars[i]=qval;
	end;
	
	if last.idvarval then flag=1;
	drop i;
	label atc="ATC Level 1 Term";
    label atccd="ATC Level 1 Code";
    label cmdicver="Medical Coding Dictionary & Version";
run;

data final_supp;
	set array_transpose;
	where flag=1;
	cmseq=input(idvarval,best12.);
	drop flag qnam qlabel qeval qorig qval idvar idvarval;
run;

data merged_supp_cm;
	merge  out.final_cm final_supp;
	by usubjid cmseq;
	drop rdomain;
run;
data merger_dm;
	set sdtm.dm;
	label armcd="ARMCD";
	keep usubjid rfstdtc rfendtc studyid arm armcd;
run;
data merged_dm_supp_cm;
	merge merged_supp_cm(in=a) merger_dm(in=b);
	if a and b;
	by usubjid;
	label TRTP="Planned Treatment";
	TRTP=ARM;
	drop arm;
run;

data merged_std_end;
	merge merged_dm_supp_cm(in=a) sdtm.adcm_adsl(in=b);
	if a and b;
	by usubjid;
	label TRTSDT="Treatment Start Date";
	label TRTEDT="Treatment End Date";
	drop saffl trtan trta;
run;

data ast_end;
	length ASTDTF $6;
	length AENDTF $6;
	length ONTRTFL $7;
	length PREFL $5;
	label ASTDTF="Analysis Start Impuation Flag";
	label AENDTF="Analysis End Impuation Flag";
	label ONTRTFL="On Treatment Flag";
	label PREFL="Prior Treament Flag";
	label ASTDT="Analysis Start Date";
	label AENDT="Analysis End Date";
	set merged_std_end;
	if length(cmstdtc)=4 then do;
	ASTDT=input(cats('01JAN', cmstdtc), date9.);
	ASTDTF="M";
	end;
	else do;
	ASTDT=input(cmstdtc,yymmdd10.);
	end;
	if length(cmendtc)=7 then do;
	year=input(substr(cmendtc, 1, 4), 4.);
	month=input(substr(cmendtc, 6, 2), 2.);
	AENDT = mdy(month, 1, year);
	AENDTF="D";
	end;
	else do;
	AENDT=input(cmendtc,yymmdd10.);
	end;
	format astdt aendt date9.;
	drop year month;
run;

data flags;
	set ast_end;
	sd=input(put(astdt,date9.),date9.);
	ed=input(put(aendt,date9.),date9.);
    trted = input(put(trtedt, date9.),date9.);
    trtsd = input(put(trtsdt, date9.),date9.);
	if sd<trted and cmenrf="ONGOING" then ONTRTFL="Y";
	if sd<trtsd and ed ne "" then PREFL="Y";
	drop sd ed trted trtsd;
run;
proc sort data=flags out=adam.final_adcm;
	by USUBJID CMTRT CMSTDTC;
run;
proc print data=adam.final_adcm;
run;
proc compare base=adam.final_adcm compare=sdtm.adcm;
run;
proc contents data=flags varnum;
run;
proc contents data=sdtm.adcm varnum;
run;