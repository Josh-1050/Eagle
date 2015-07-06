{\rtf1\ansi\ansicpg1252\deff0\deflang1035{\fonttbl{\f0\fswiss\fcharset0 Arial;}}
{\*\generator Msftedit 5.41.15.1515;}\viewkind4\uc1\pard\f0\fs20 ; ******************************************************************************\par
;\par
;  LiniStepper v2\par
;  PIC 16F84 / 16F628 / 16F628A code (updated 628A June 2007)\par
;  Copyright Aug 2002 - Nov 2009 - Roman Black   http://www.romanblack.com\par
;\par
;  PIC assembler code for the LiniStepper stepper motor driver board.\par
;  200/400/1200/3600 steps\par
;\par
;  v2.0\tab New version 2.0; 2nd Nov 2009.\par
;\tab\tab * modified v1 source to work with new Lini v2 PCB.\par
;\tab\tab * STEP and DIR are the same, but POWER is now "ENABLE" (active LOW)\par
;\tab\tab   (so the POWER pin function is inverted in Lini v2) \par
;  v2.1   Updated 16th Nov 2010.\par
;\tab\tab Now incorporates update suggested by Brian D Freeman; improves\par
;         performance by skipping the current calculation on the hi-lo\par
;         transition of the step input.\par
;\par
;  (set mplab TABS to 5 for best viewing this .asm file)\par
;******************************************************************************\par
\par
\par
;==============================================================================\par
; mplab settings\par
\par
\tab ERRORLEVEL -224\tab\tab ; suppress annoying message because of option/tris\par
\tab ERRORLEVEL -302\tab\tab ; suppress message because of bank select in setup ports\par
\par
\tab LIST b=5, n=97, t=ON, st=OFF\tab\tab ;\par
\tab ; absolute listing tabs=5, lines=97, trim long lines=ON, symbol table=OFF\par
\par
;==============================================================================\par
; processor defined\par
\par
\tab ;include <p16f84A.inc>\par
\tab ;include <p16f628.inc>\par
\tab include <p16f628A.inc>\par
\par
; processor config\par
\par
\tab IFDEF __16F84A\par
\tab\tab __CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC\par
\tab ENDIF\par
\tab IFDEF __16F628\par
\tab\tab __CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC & _MCLRE_ON & _BODEN_OFF & _LVP_OFF\par
\tab ENDIF\par
\tab IFDEF __16F628A\par
\tab\tab __CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC & _MCLRE_ON & _BODEN_OFF & _LVP_OFF\par
\tab ENDIF\par
\par
\par
;==============================================================================\par
; Variables here\par
\par
\tab ;-------------------------------------------------\par
\tab IFDEF __16F84A\par
\tab\tab #define RAM_START\tab 0x0C\par
\tab\tab #define RAM_END\tab RAM_START+d'68' \tab\tab ; 16F84 has only 68 ram\par
\tab ENDIF\par
\tab IFDEF __16F628\par
\tab\tab #define RAM_START\tab 0x20\tab\par
\tab\tab #define RAM_END\tab RAM_START+d'96' \tab\tab ; F628 has 96 ram\par
\tab ENDIF\par
\tab IFDEF __16F628A\par
\tab\tab #define RAM_START\tab 0x20\tab\par
\tab\tab #define RAM_END\tab RAM_START+d'96' \tab\tab ; F628A has 96 ram\par
\tab ENDIF\par
\tab ;-------------------------------------------------\par
\tab CBLOCK \tab RAM_START\par
\par
\tab\tab status_temp\tab\tab ; used for int servicing\par
\tab\tab w_temp\tab\tab\tab ; used for int servicing\par
\par
\tab\tab step\tab\tab\tab\tab ; (0-71) ustep position!\par
\tab\tab steptemp\tab\tab\tab ; for calcs\par
\par
\tab\tab phase\tab\tab\tab ; stores the 4 motor phase pins 0000xxxx\par
\tab\tab current1\tab\tab\tab ; for current tween pwm\par
\tab\tab current2\tab\tab\tab ; for current tween pwm\par
\par
\tab\tab inputs\tab\tab\tab ; stores new input pins\par
\tab\tab inputs_last\tab\tab ; stores last states of input pins\par
\par
\tab ENDC\par
\par
\tab ;-------------------------------------------------\par
\tab ; PIC input pins for porta\par
\par
\tab #define \tab STEP\tab\tab\tab 0\tab\tab ; / = move 1 step, \\=do nothing\par
\tab #define \tab DIR\tab\tab\tab 1\tab\tab ; lo= cw,  hi=ccw\par
\tab #define \tab POWER\tab\tab 2\tab\tab ; lo=full power, hi=half power\par
\tab\tab\tab ; (Note! POWER pin was inverted for v2 !!!)\par
\tab ;-------------------------------------------------\par
\tab ; Custom instructions!\par
\par
\tab #define\tab skpwne\tab\tab skpnz\tab\tab\tab ; after subxx, uses zero\par
\tab #define\tab skpweq\tab\tab skpz\tab\tab\tab\tab ; after subxx, uses zero\par
\tab #define\tab skpwle\tab\tab skpc\tab\tab\tab\tab ; after subxx, uses carry\par
\tab #define\tab skpwgt\tab\tab skpnc\tab\tab\tab ; after subxx, uses carry\par
\par
;==============================================================================\par
; CODE GOES HERE\par
\par
\tab org 0x0000 \tab\tab\tab ; Set program memory base at reset vector 0x00\par
reset\par
\tab goto main\tab\tab\tab\tab ;\par
\par
\par
\par
;==============================================================================\par
; INTERRUPT vector here\par
\tab org 0x0004 \tab\tab\tab ; interrupt routine must start here\par
int_routine\par
\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; first we preserve w and status register\par
\par
\tab movwf w_temp      \tab\tab ; save off current W register contents\par
\tab movf\tab STATUS,w          \tab ; move status register into W register\par
\tab movwf status_temp       \tab ; save off contents of STATUS register\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; we get here every 256 timer0 ticks  3900Hz\par
\tab\tab\tab\tab\tab\tab ; int body code here if you want\par
\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; finally we restore w and status registers and\par
\tab\tab\tab\tab\tab\tab ; clear TMRO int flag now we are finished.\par
int_exit\par
\tab bcf INTCON,T0IF\tab\tab ; reset the tmr0 interrupt flag\par
\tab movf status_temp,w     \tab ; retrieve copy of STATUS register\par
\tab movwf STATUS            \tab ; restore pre-isr STATUS register contents\par
\tab swapf w_temp,f\par
\tab swapf w_temp,w          \tab ; restore pre-isr W register contents\par
\tab retfie\tab\tab\tab\tab ; return from interrupt\par
\tab ;-------------------------------------------------\par
\par
;==============================================================================\par
\par
\par
\par
\par
;******************************************************************************\par
; MOVE MOTOR  \tab\tab   sets 8 portb output pins to control motor\par
;******************************************************************************\par
; NOTE!! var step is used for sequencing the 0-71 steps\par
; uses tables! so keep it first in the code and set PCLATH to page 0\par
\par
;------------------\par
move_motor\tab\tab\tab\tab ; goto label\par
;------------------\par
\par
\tab ;-------------------------------------------------\par
\tab ; this code controls the phase sequencing and current\par
\tab ; settings for the motor.\par
\par
\tab ; there are always 72 steps (0-71)\par
\par
\tab ; we can split the main table into 2 halves, each have identical\par
\tab ; current sequencing. That is only 12 entries for hardware current.\par
\par
\tab ; Then can x3 the table to get 36 table entries which cover all 72 steps.\par
\tab ; the 36 entries jump to 36 code pieces, which set the current values\par
\tab ; for the 2 possible tween steps... We need 2 current values, one\par
\tab ; for the x2 value and one for the x1 value.\par
\tab ;-------------------------------------------------\par
\tab ; PHASE SEQUENCING (switch the 4 coils)\par
\par
\tab ; there are 4 possible combinations for the phase switching:\par
\tab ; each have 18 steps, total 72 steps:\par
\par
\tab ;\tab A+ B+\tab range 0\tab\tab step 0-17\par
\tab ;\tab A- B+\tab range 1\tab\tab 18-35\par
\tab ;\tab A- B-\tab range 2\tab\tab 36-53\par
\tab ;\tab A+ B-\tab range 3\tab\tab 54-71\par
\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; find which of the 4 ranges we are in\par
\tab movf step,w\tab\tab\tab ; get step\par
\tab movwf steptemp\tab\tab\tab ; store as working temp\par
\par
\tab movf steptemp,w\tab\tab ;\par
\tab sublw d'35'\tab\tab\tab ; sub to test\par
\tab skpwle\tab\tab\tab\tab ;\par
\tab goto half_hi\tab\tab\tab ; wgt, steptemp is 36-71 (upper half)\par
\par
\tab ;-------------------------\par
half_low\tab\tab\tab\tab\tab ; wle, steptemp is 0-35\par
\par
\tab movf steptemp,w\tab\tab ;\par
\tab sublw d'17'\tab\tab\tab ; sub to test\par
\tab skpwle\tab\tab\tab\tab ;\par
\tab goto range1\tab\tab\tab ; wgt\par
\tab\par
range0\tab\tab\tab\tab\tab ; wle\par
\tab movlw b'00000101'\tab\tab ; 0101 = A+ B+\par
\tab goto phase_done\tab\tab ;\par
\par
range1\par
\tab movlw b'00001001'\tab\tab ; 1001 = A- B+\par
\tab goto phase_done\tab\tab ;\par
\par
\tab ;-------------------------\par
half_hi\tab\tab\tab\tab\tab ; steptemp is 36-71\par
\tab\tab\tab\tab\tab\tab ; NOTE! must subtract 36 from steptemp, so it\par
\tab\tab\tab\tab\tab\tab ; will become 0-35 and ok with table later!\par
\tab movlw d'36'\tab\tab\tab ; subtract 36 from steptemp,\par
\tab subwf steptemp,f\tab\tab ; (now steptemp is 0-35)\par
\par
\tab\tab\tab\tab\tab\tab ; now find the range\par
\tab movf steptemp,w\tab\tab ;\par
\tab sublw d'17'\tab\tab\tab ; sub to test\par
\tab skpwle\tab\tab\tab\tab ;\par
\tab goto range3\tab\tab\tab ; wgt\par
\tab\par
range2\tab\tab\tab\tab\tab ; wle\par
\tab movlw b'00001010'\tab\tab ; 1010 = A- B-\par
\tab goto phase_done\tab\tab ;\par
\par
range3\par
\tab movlw b'00000110'\tab\tab ; 0110 = A+ B-\par
\par
phase_done\tab\tab\tab\tab ; note! steptemp is always 0-35 by here\par
\tab movwf phase\tab\tab\tab ; store phase values\par
\par
\tab ;-------------------------------------------------\par
\tab ; at this point we have the phasing done and stored as the last\par
\tab ; 4 bits in var phase; 0000xxxx\par
\tab\par
\tab ; now we have 36 possible current combinations, which we can do\par
\tab ; by separate code fragments, from a jump table.\par
\par
\tab ; as we have 2 power modes; full and low power, we\par
\tab ; need 2 tables.\par
\par
\tab ;-------------------------------------------------\par
\par
\tab btfsc inputs,POWER\tab\tab ; select table to use\par
\tab goto table_lowpower\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
\tab ; HIGH POWER TABLE\par
\tab ;-------------------------------------------------\par
\par
table_highpower\tab\tab\tab ;\par
\par
\tab movf steptemp,w\tab\tab ; add steptemp to the PCL\par
\tab addwf PCL,f\tab\tab\tab ; \par
\tab\tab\tab\tab\tab\tab ; here are the 36 possible values;\par
\tab ;-------------------------\par
\tab goto st00\tab\tab\tab\tab ; * (hardware 6th steps)\par
\tab goto st01\tab\tab\tab\tab ;   (pwm tween steps)\par
\tab goto st02\tab\tab\tab\tab ;   (pwm tween steps)\par
\tab goto st03\tab\tab\tab\tab ; *\par
\tab goto st04\tab\tab\tab\tab ; \par
\tab goto st05\tab\tab\tab\tab ; \par
\par
\tab goto st06\tab\tab\tab\tab ; *\par
\tab goto st07\tab\tab\tab\tab ;\par
\tab goto st08\tab\tab\tab\tab ;\par
\tab goto st09\tab\tab\tab\tab ; *\par
\tab goto st10\tab\tab\tab\tab ;\par
\tab goto st11\tab\tab\tab\tab ;\par
\par
\tab goto st12\tab\tab\tab\tab ; *\par
\tab goto st13\tab\tab\tab\tab ;\par
\tab goto st14\tab\tab\tab\tab ;\par
\tab goto st15\tab\tab\tab\tab ; *\par
\tab goto st16\tab\tab\tab\tab ;\par
\tab goto st17\tab\tab\tab\tab ;\par
\par
\tab goto st18\tab\tab\tab\tab ; *\par
\tab goto st19\tab\tab\tab\tab ;\par
\tab goto st20\tab\tab\tab\tab ;\par
\tab goto st21\tab\tab\tab\tab ; *\par
\tab goto st22\tab\tab\tab\tab ;\par
\tab goto st23\tab\tab\tab\tab ;\par
\par
\tab goto st24\tab\tab\tab\tab ; *\par
\tab goto st25\tab\tab\tab\tab ;\par
\tab goto st26\tab\tab\tab\tab ;\par
\tab goto st27\tab\tab\tab\tab ; *\par
\tab goto st28\tab\tab\tab\tab ;\par
\tab goto st29\tab\tab\tab\tab ;\par
\par
\tab goto st30\tab\tab\tab\tab ; *\par
\tab goto st31\tab\tab\tab\tab ;\par
\tab goto st32\tab\tab\tab\tab ;\par
\tab goto st33\tab\tab\tab\tab ; *\par
\tab goto st34\tab\tab\tab\tab ;\par
\tab goto st35\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
\tab ; LOW POWER TABLE\par
\tab ;-------------------------------------------------\par
\tab ; as low power mode is for wait periods we don't need to\par
\tab ; maintain the full step precision and can wait on the\par
\tab ; half-step (400 steps/rev). This means much easier code tables.\par
\tab ; The nature of the board electronics is not really suited\par
\tab ; for LOW power microstepping, but it could be programmed here\par
\tab ; if needed.\par
\par
\tab ; NOTE!! uses my hi-torque half stepping, not normal half step.\par
\par
\tab ;  doing half stepping with the 55,25 current values gives;\par
\tab ; 55+25 = 80\par
\tab ; max current 100+100 = 200\par
\tab ; typical (high) current 100+50 = 150\par
\tab ; so low power is about 1/2 the current of high power mode,\par
\tab ; giving about 1/4 the motor heating and half the driver heating.\par
\par
\tab ; for now it uses only half-steps or 8 separate current modes.\par
\tab ; we only have to use 4 actual current modes as\par
\tab ; the table is doubled like the table_highpower is.\par
\par
\tab ; NOTE!! I have left the table full sized so it can be modified\par
\tab ; to 1200 or 3600 steps if needed.\par
\tab ;-------------------------------------------------\par
\par
table_lowpower\tab\tab\tab\tab ;\par
\par
\tab movf steptemp,w\tab\tab ; add steptemp to the PCL\par
\tab addwf PCL,f\tab\tab\tab ; \par
\tab\tab\tab\tab\tab\tab ; here are the 36 possible values;\par
\tab ;-------------------------\par
\tab\tab\tab\tab\tab\tab ; A+ B+ (A- B-)\par
\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\tab 55,25 (100,45) current low (high)\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\par
\tab goto lp00\tab\tab\tab\tab ;\par
\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\tab 25,55 (45,100)\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\par
\tab goto lp09\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\tab\tab\tab\tab\tab\tab ; A- B+ (A+ B-)\par
\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\tab 25,55 (45,100)\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\par
\tab goto lp18\tab\tab\tab\tab ;\par
\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\tab 55,25 (100,45)\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\par
\tab goto lp27\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
\tab ; all tables done, no more tables after this point!\par
\tab ;-------------------------------------------------\par
\tab ; next are the 36 code fragments for the high power table.\par
\par
\tab ; CURRENT INFO.\par
\tab ; hardware requires that we send the entire 8 bits to the motor\par
\tab ; at one time, to keep pwm fast.\par
\par
\tab ; ----xxxx,  where xxxx is the coils on/off phasing (done)\par
\tab ; xxxx----,  where xxxx is the current settings for the A and B phases;\par
\tab ; xx------,  where xx is current for A phase\par
\tab ; --xx----,  where xx is current for B phase\par
\par
\tab ; hardware currents for 6th stepping have 4 possible values;\par
\tab ; 00  =  0% current\par
\tab ; 01  =  25% current\par
\tab ; 10  =  55% current\par
\tab ; 11  =  100% current\par
\par
\tab ;-------------------------------------------------\par
\tab ; PWM INFO.\par
\tab ; hardware gives us 6th steps, or 1200 steps/rev.\par
\tab ; to get 3600 steps/rev we need TWO more\par
\tab ; "tween" steps between every proper hardware 6th step.\par
\par
\tab ; to do this we set 2 currents, current1 and current2.\par
\tab ; then we do FAST pwm, with 2 time units at current2,\par
\tab ; and 1 time unit at current1.\par
\tab ; this gives a current which is between the two currents,\par
\tab ; proportionally closer to current2. (2/3 obviously)\par
\tab ; this gives the ability to get 2 evenly spaced "tween" currents\par
\tab ; between our hardware 6th step currents, and go from 1200 to 3600.\par
\par
\tab ; the next 36 code fragments set the 2 currents desired, then\par
\tab ; we goto a fast-pwm loop (same loop used for all currents)\par
\tab ; which modulates between the 2 currents and gives final\par
\tab ; output current.\par
\tab ;-------------------------------------------------\par
\par
st00\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ; get coil phasing (is 0000xxxx)\par
\tab iorlw b'11000000'\tab\tab ; set currents; 100,0 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st01\tab\tab\tab\tab\tab\tab ; (tween step)\par
\tab movf phase,w\tab\tab\tab ; get coil phasing\par
\tab iorlw b'11000000'\tab\tab ; set 100,0 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st02\tab\tab\tab\tab\tab\tab ; (tween step)\par
\tab movf phase,w\tab\tab\tab ; get coil phasing\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11000000'\tab\tab ; set 100,0 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st03\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st04\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st05\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st06\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st07\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st08\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st09\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st10\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st11\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st12\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st13\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st14\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
st15\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st16\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'00110000'\tab\tab ; set 0,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st17\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'00110000'\tab\tab ; set 0,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\tab ;-------------------------\par
\par
st18\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'00110000'\tab\tab ; set 0,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st19\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'00110000'\tab\tab ; set 0,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st20\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'00110000'\tab\tab ; set 0,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st21\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st22\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st23\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01110000'\tab\tab ; set 25,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st24\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st25\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st26\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10110000'\tab\tab ; set 55,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st27\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st28\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st29\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11110000'\tab\tab ; set 100,100 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st30\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st31\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st32\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11100000'\tab\tab ; set 100,55 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------\par
\par
st33\tab\tab\tab\tab\tab\tab ; (6th step)\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st34\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11000000'\tab\tab ; set 100,0 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
st35\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11000000'\tab\tab ; set 100,0\par
\tab movwf current2\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'11010000'\tab\tab ; set 100,25 \par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\tab\tab\tab\tab\tab\tab ; high power table done!\par
\par
\par
\tab ;-------------------------------------------------\par
\tab ; next are the 4 code fragments for the low power table.\par
\tab ; (no PWM is used)\par
\tab ;-------------------------------------------------\par
\par
lp00\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10010000'\tab\tab ; set 55,25 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
lp09\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01100000'\tab\tab ; set 25,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
lp18\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'01100000'\tab\tab ; set 25,55 \par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
lp27\tab\tab\tab\tab\tab\tab ;\par
\tab movf phase,w\tab\tab\tab ;\par
\tab iorlw b'10010000'\tab\tab ; set 55,25\par
\tab movwf current2\tab\tab\tab ;\par
\tab movwf current1\tab\tab\tab ;\par
\tab goto pwm\tab\tab\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
\par
\par
;------------------------------------------------------------------------------\par
\par
\par
\par
\par
;******************************************************************************\par
;  Main \par
;******************************************************************************\par
;\par
;------------------\par
main\tab\tab\tab\tab\tab\tab ; goto label\par
;------------------\par
\par
\tab ;---------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; do initial setup for ports and ints and stuff\par
\tab call setup\tab\tab\tab ; this is our only proper call...\par
\tab\tab\tab\tab\tab\tab ; it is called only once, and does not really need\par
\tab\tab\tab\tab\tab\tab ; to be a function.\par
\tab ;---------------------------------------------\par
\tab ; main operating loop is here.\par
\tab ;---------------------------------------------\par
\par
\tab goto move_motor\tab\tab ; will set the motor to step 0,\par
\tab\tab\tab\tab\tab\tab ; and loop permanently from there\par
\par
\tab ;---------------------------------------------\par
\tab goto main\tab\tab\tab\tab ; safe loop, should never get here anyway.\par
\par
;==============================================================================\par
\par
\par
\par
\par
;******************************************************************************\par
; NEW INPUTS   input change was detected\par
;******************************************************************************\par
;\par
;------------------\par
new_inputs\tab\tab\tab\tab ; goto tag\par
;------------------\par
\par
\tab ;-------------------------------------------------\par
\tab ; when we enter here:\par
\tab ; * one or more PORTA inputs have just changed\par
\tab ; * inputs_last\tab contains last PORTA inputs values\par
\tab ; * inputs\tab\tab contains new PORTA inputs values\par
\tab ;-------------------------------------------------\par
\tab ; must first detect which input pins changed.\par
\par
\tab ; ---x----\tab RA4\tab * mode bit1\tab    ( 00=200 step\tab 01=400 step\par
\tab ; ----x---\tab RA3\tab * mode bit0\tab\tab 10=1200 step\tab 11=3600 step )\par
\tab ; -----x--\tab RA2\tab * power  (Lini v2; now 0 = full power!)\par
\tab ; ------x-\tab RA1\tab * direction\par
\tab ; -------x\tab RA0\tab * step\par
\par
\tab ; if step went hi, we move the step (step++ or step--)\par
\par
\tab ; if step went low, ignore\par
\tab ; ignore change in direction pin\par
\tab ; ignore change in power pin\par
\tab ; ignore change in mode pins\par
\tab ; (all pins besides step are handled automatically in move_motor)\par
\tab ;-------------------------------------------------\par
\par
\tab movf inputs,w\tab\tab\tab ; xor to compare new inputs with last values\par
\tab xorwf inputs_last,f\tab\tab ; now inputs_last has the diff.\par
\par
\tab btfss inputs_last,STEP\tab ; test if step input changed\par
\tab goto ni_end\tab\tab\tab ; \par
\par
\tab\tab\tab\tab\tab\tab ; step input changed!\par
\tab btfsc inputs,STEP\tab\tab ; test if change was lo-hi or hi-lo\par
\tab goto trans_hi\tab\tab\tab ; lo-hi, so process a step!\par
\par
\tab\tab\tab\tab\tab\tab ; hi-lo, so ignore this transition\par
\tab bcf inputs_last,STEP\tab ; record new state of step pin\par
\tab goto pwm\tab\tab\tab\tab ; fast exit back to pwm()\par
\par
\tab ;-------------------------------------------------\par
\tab ; step input changed lo-hi!\par
\tab ; now must make a step forward or back, based\par
\tab ; on the state of the dir pin.\par
\par
\tab ; here it gets complex as we have 4 operating modes,\par
\tab ; determined by the state of the 2 input pins RA4 and RA3;\par
\par
\tab ; ---00---\tab 200 steps\par
\tab ; ---01---\tab 400 steps\par
\tab ; ---10---\tab 1200 steps\par
\tab ; ---11---\tab 3600 steps\par
\par
\tab ; there are 4 separate code systems to handle stepping \par
\tab ; in the 4 modes;\par
\tab ;-------------------------------------------------\par
trans_hi\par
\tab\tab\tab\tab\tab\tab ; find which of the 4 modes we are in\par
\tab btfss inputs,4\tab\tab\tab ; test hi bit\par
\tab goto mode_lo\tab\tab\tab ;\par
\par
mode_hi\tab\tab\tab\tab\tab ; must be 1200 or 3600\par
\par
\tab btfss inputs,3\tab\tab\tab ; test lo bit\par
\tab goto mode_1200\tab\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
mode_3600\tab\tab\tab\tab\tab ; 3600 mode (72/1)\par
\tab\tab\tab\tab\tab\tab ; each step is 1\par
\par
\tab btfss inputs,DIR\tab\tab ; test direction input\par
\tab goto m36_up\tab\tab\tab ;\par
\par
m36_down\par
\tab decf step,f\tab\tab\tab ; step--\par
\tab btfss step,7\tab\tab\tab ; test for roll under <0\par
\tab goto ni_end\tab\tab\tab ; ok\par
\tab\tab\tab\tab\tab\tab ; rolled under!\par
\tab movlw d'71'\tab\tab\tab ; force to top step (72-1)\par
\tab movwf step\tab\tab\tab ;\par
\tab goto ni_end\tab\tab\tab ;\par
\par
m36_up\par
\tab incf step,f\tab\tab\tab ; step++\par
\tab movf step,w\tab\tab\tab ; test for roll over >71\par
\tab sublw d'71'\tab\tab\tab ; sub to test\par
\tab skpwle\tab\tab\tab\tab ;\par
\tab clrf step\tab\tab\tab\tab ; wgt, rolled over so force to step 0\par
\par
\tab goto ni_end\tab\tab\tab ;\par
\tab ;-------------------------------------------------\par
mode_1200\tab\tab\tab\tab\tab ; 1200 mode (72/3)\par
\tab\tab\tab\tab\tab\tab ; each step is mod 3 (0,3,6,9,12 - 66, 69 etc)\par
\par
\tab btfss inputs,DIR\tab\tab ; test direction input\par
\tab goto m12_up\tab\tab\tab ;\par
\par
m12_down\par
\tab movlw d'3'\tab\tab\tab ; amount to subtract\par
\tab subwf step,f\tab\tab\tab ; step-=3\par
\tab btfss step,7\tab\tab\tab ; test for roll under <0\par
\tab goto ni_end\tab\tab\tab ; ok\par
\tab\tab\tab\tab\tab\tab ; rolled under!\par
\tab movlw d'69'\tab\tab\tab ; force to top step (72-3)\par
\tab movwf step\tab\tab\tab ;\par
\tab goto ni_end\tab\tab\tab ;\par
\par
m12_up\par
\tab movlw d'3'\tab\tab\tab ; amount to add\par
\tab addwf step,f\tab\tab\tab ; step+=3\par
\tab\tab\tab\tab\tab\tab ;\par
\tab movf step,w\tab\tab\tab ; test for roll over >69\par
\tab sublw d'69'\tab\tab\tab ; sub to test\par
\tab skpwle\tab\tab\tab\tab ;\par
\tab clrf step\tab\tab\tab\tab ; wgt, rolled over so force to step 0\par
\par
\tab goto ni_end\tab\tab\tab ;\par
\tab ;-------------------------------------------------\par
mode_lo\tab\tab\tab\tab\tab ; must be 200 or 400\par
\tab btfss inputs,3\tab\tab\tab ; test lo bit\par
\tab goto mode_200\tab\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
mode_400\tab\tab\tab\tab\tab ; 400 mode (72/9)\par
\tab\tab\tab\tab\tab\tab ; note! we do special half stepping here.\par
\tab\tab\tab\tab\tab\tab ; there are ONLY 8 valid steps:\par
\tab\tab\tab\tab\tab\tab ; 4, 13, 22, 31, 40, 49, 58, 67\par
\tab\tab\tab\tab\tab\tab ; these steps give 100,45 and 35,100 combos, good\par
\tab\tab\tab\tab\tab\tab ; enough for now. (should average 100,41)\par
\par
\tab btfss inputs,DIR\tab\tab ; test direction input\par
\tab goto m4_up\tab\tab\tab ;\par
\par
m4_down\par
\tab movlw d'9'\tab\tab\tab ; amount to subtract\par
\tab subwf step,f\tab\tab\tab ; step-=9\par
\tab btfss step,7\tab\tab\tab ; test for roll under <0\par
\tab goto ni_end\tab\tab\tab ; ok\par
\tab\tab\tab\tab\tab\tab ; rolled under!\par
\tab movlw d'67'\tab\tab\tab ; force to top (full) step \par
\tab movwf step\tab\tab\tab ;\par
\tab goto ni_end\tab\tab\tab ;\par
\par
m4_up\par
\tab movlw d'9'\tab\tab\tab ; amount to add\par
\tab addwf step,f\tab\tab\tab ; step+=9\par
\tab\tab\tab\tab\tab\tab ;\par
\tab movf step,w\tab\tab\tab ; test for roll over\par
\tab sublw d'67'\tab\tab\tab ; sub to test\par
\tab skpwgt\tab\tab\tab\tab ;\par
\tab goto ni_end\tab\tab\tab ; wle, is ok\par
\par
\tab movlw d'4'\tab\tab\tab ; wgt, rolled over so force to bottom step 5\par
\tab movwf step\tab\tab\tab ;\par
\par
\tab goto ni_end\tab\tab\tab ;\par
\tab ;-------------------------------------------------\par
mode_200\tab\tab\tab\tab\tab ; 200 mode (72/18)\par
\tab\tab\tab\tab\tab\tab ; NOTE!! this has special needs as we can't use\par
\tab\tab\tab\tab\tab\tab ; step 0, we need to stay on the "2 steps on" steps.\par
\tab\tab\tab\tab\tab\tab ; there are ONLY 4 valid steps;  9, 27, 45, 63\par
\par
\tab btfss inputs,DIR\tab\tab ; test direction input\par
\tab goto m2_up\tab\tab\tab ;\par
\par
m2_down\par
\tab movlw d'18'\tab\tab\tab ; amount to subtract\par
\tab subwf step,f\tab\tab\tab ; step-=18\par
\tab btfss step,7\tab\tab\tab ; test for roll under <0\par
\tab goto ni_end\tab\tab\tab ; ok\par
\tab\tab\tab\tab\tab\tab ; rolled under!\par
\tab movlw d'63'\tab\tab\tab ; force to top (full) step (72-(18/2))\par
\tab movwf step\tab\tab\tab ;\par
\tab goto ni_end\tab\tab\tab ;\par
\par
m2_up\par
\tab movlw d'18'\tab\tab\tab ; amount to add\par
\tab addwf step,f\tab\tab\tab ; step+=18\par
\tab\tab\tab\tab\tab\tab ;\par
\tab movf step,w\tab\tab\tab ; test for roll over\par
\tab sublw d'63'\tab\tab\tab ; sub to test\par
\tab skpwgt\tab\tab\tab\tab ;\par
\tab goto ni_end\tab\tab\tab ; wle, is ok\par
\par
\tab movlw d'9'\tab\tab\tab ; wgt, rolled over so force to bottom step 9\par
\tab movwf step\tab\tab\tab ;\par
\par
\tab goto ni_end\tab\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
ni_end\par
\tab movf inputs,w\tab\tab\tab ; save a copy of the inputs\par
\tab movwf inputs_last\tab\tab ;\par
\par
\tab goto move_motor\tab\tab ; go and make it all happen\par
\par
;------------------------------------------------------------------------------\par
\par
\par
\par
\par
;******************************************************************************\par
; PWM\tab\tab is the fast pwm loop\par
;******************************************************************************\par
; NOTE!! we enter the code in the middle of the loop!\par
\par
\tab ;-------------------------------------------------\par
\tab ; the 2 target currents were set in the move_motor code.\par
\par
\tab ; what this function does is spend 2 time units at current2,\par
\tab ; and 1 time unit at current1.\par
\tab ; actual is 8 clocks at current2\par
\tab ; and 4 clocks at current 1\par
\tab ; total 12 cycles, so 333 kHz with 16MHz resonator.\par
\par
\tab ; this gives an average pwm current of 2/3 the way between\par
\tab ; current2 and current1.\par
\par
\tab ; the routine is kept short to keep pwm frequency high, so it\par
\tab ; is easy to smooth in hardware by the ramping caps.\par
\par
\tab ; IMPORTANT! is timed by clock cycles, don't change this code!\par
\tab ; it also checks for any change in input pins here\par
\par
\tab ; the 8/4 code seen here was supplied by Eric Bohlman (thanks!)\par
\tab ;-------------------------------------------------\par
pwm_loop\par
\tab\tab\tab\tab\tab\tab ; first output current1 to motor\par
\tab movf current1,w\tab\tab ; get currents and phase switching\par
\tab movwf PORTB\tab\tab\tab ; send to motor!\par
\par
\tab nop\tab\tab\tab\tab\tab ; timing delay\par
\tab nop\tab\tab\tab\tab\tab ;\par
\tab\tab\tab\tab\tab\tab ; (4 cycles)\par
\tab ;-------------------------\par
pwm\tab\tab\tab\tab\tab\tab ; main entry!\par
\tab\tab\tab\tab\tab\tab ; better to enter at current2 for motor power.\par
\par
\tab\tab\tab\tab\tab\tab ; now output current2\par
\tab movf current2,w\tab\tab ;\par
\tab movwf PORTB\tab\tab\tab ; send to motor!\par
\tab nop\tab\tab\tab\tab\tab ; safe wait 250nS\par
\par
\tab\tab\tab\tab\tab\tab ; now test input pins\par
\tab movf PORTA,w\tab\tab\tab ; get pin values from port\par
\par
\tab xorwf inputs_last,w\tab\tab ; xor to compare new inputs with last values\par
\tab skpnz\par
\tab goto pwm_loop\tab\tab\tab ; z, inputs not changed, so keep looping\par
\tab\tab\tab\tab\tab\tab ; (8 cycles)\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; nz, one or more input pins have changed!\par
\tab xorwf inputs_last,w\tab\tab ; restore xored value back to the orig inputs value\par
\tab movwf inputs\tab\tab\tab ;\par
\par
\tab goto new_inputs\tab\tab ; \par
\tab ;-------------------------------------------------\par
\par
;------------------------------------------------------------------------------\par
\par
\par
\par
\par
\par
\par
;******************************************************************************\par
;  SETUP   sets port directions and interrupt stuff etc,\par
;******************************************************************************\par
; NOTE!! is the only proper funtion, is done before other activity\par
\par
;------------------\par
setup\tab\tab\tab\tab\tab ; routine tag\par
;------------------\par
\par
\tab ;-------------------------------------------------\par
\tab ; Note! there are added bits for the 16F628!\par
\tab ; here we set up peripherals and port directions.\par
\tab ; this will need to be changed for different PICs.\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; OPTION setup\par
\tab movlw b'10000010'\tab\tab ;\par
\tab\tab ;  x-------\tab\tab ; 7, 0=enable, 1=disable, portb pullups\par
\tab\tab ;  -x------\tab\tab ; 6, 1=/, int edge select bit\par
\tab\tab ;  --x-----\tab\tab ; 5, timer0 source, 0=internal clock, 1=ext pin.\par
\tab\tab ;  ---x----\tab\tab ; 4, timer0 ext edge, 1=\\\par
\tab\tab ;  ----x---\tab\tab ; 3, prescaler assign, 1=wdt, 0=timer0\par
\tab\tab ;  -----x--\tab\tab ; 2,1,0, timer0 prescaler rate select\par
\tab\tab ;  ------x-\tab\tab ;   000=2, 001=4, 010=8, 011=16, etc.\par
\tab\tab ;  -------x\tab\tab ; \par
\tab\tab\tab\tab\tab\tab ;\par
\tab banksel OPTION_REG\tab\tab ; go proper reg bank\par
\tab movwf OPTION_REG\tab\tab ; load data into OPTION_REG\par
\tab banksel 0\tab\tab\tab\tab ;\par
\tab ;-------------------------------------------------\par
\tab ; note! check for 16F628 (and A) and do extra setup for it.\par
\par
\tab IFDEF  __16F628\par
\tab\tab banksel VRCON\tab\tab ; do bank 1 stuff\par
\tab\tab clrf VRCON\tab\tab ; disable Vref\par
\tab\tab clrf PIE1\tab\tab\tab ; disable pi etc\par
\tab\tab banksel 0\tab\tab\tab ;\par
\par
\tab\tab clrf T1CON\tab\tab ; disable timer1\par
\tab\tab clrf T2CON\tab\tab ; disable timer2\par
\tab\tab clrf CCP1CON\tab\tab ; disable CCP module\par
\par
\tab\tab movlw b'00000111'\tab ; disable comparators\par
\tab\tab movwf CMCON\tab\tab ;\par
\tab ENDIF\par
\tab IFDEF  __16F628A\par
\tab\tab banksel VRCON\tab\tab ; do bank 1 stuff\par
\tab\tab clrf VRCON\tab\tab ; disable Vref\par
\tab\tab clrf PIE1\tab\tab\tab ; disable pi etc\par
\tab\tab banksel 0\tab\tab\tab ;\par
\par
\tab\tab clrf T1CON\tab\tab ; disable timer1\par
\tab\tab clrf T2CON\tab\tab ; disable timer2\par
\tab\tab clrf CCP1CON\tab\tab ; disable CCP module\par
\par
\tab\tab movlw b'00000111'\tab ; disable comparators\par
\tab\tab movwf CMCON\tab\tab ;\par
\tab ENDIF\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; PORTB pins direction setup\par
\tab\tab\tab\tab\tab\tab ; 1=input, 0=output\par
\tab clrf PORTB\tab\tab\tab ;\par
\tab\tab\tab\tab\tab\tab ;\par
\tab movlw b'00000000'\tab\tab ; all 8 portb are outputs\par
\tab\tab\tab\tab\tab\tab ;\par
\tab banksel TRISB\tab\tab\tab ; go proper reg bank\par
\tab movwf TRISB\tab\tab\tab ; send mask to portb\par
\tab banksel 0\tab\tab\tab\tab ;\par
\tab ;-------------------------------------------------\par
\par
\tab\tab\tab\tab\tab\tab ; PORTA pins direction setup\par
\tab\tab\tab\tab\tab\tab ; 1=input, 0=output\par
\tab clrf PORTA\tab\tab\tab ;\par
\par
\tab\tab\tab\tab\tab\tab ; NOTE!! all 5 PORTA pins are inputs\par
\tab movlw b'00011111'\tab\tab ;\par
\tab\tab ;  ---x----\tab\tab ; RA4\par
\tab\tab ;  ----x---\tab\tab ; RA3\par
\tab\tab ;  -----x--\tab\tab ; RA2\par
\tab\tab ;  ------x-\tab\tab ; RA1\par
\tab\tab ;  -------x\tab\tab ; RA0\par
\par
\tab banksel TRISA\tab\tab\tab ; go proper reg bank\par
\tab movwf TRISA\tab\tab\tab ; send mask to porta\par
\tab banksel 0\tab\tab\tab\tab ;\par
\tab ;-------------------------------------------------\par
\par
\tab movlw 0x00\tab\tab\tab ; set up PCLATH for all jump tables on page 0\par
\tab movwf PCLATH\tab\tab\tab ; (all tables are in move_motor)\par
\tab ;-------------------------------------------------\par
\par
\tab\tab\tab\tab\tab\tab ; CLEAR RAM! for lower bank\par
\tab movlw RAM_START\tab\tab ; first byte of ram\par
\tab movwf FSR\tab\tab\tab\tab ; load pointer\par
ram_clear_loop\par
\tab clrf INDF\tab\tab\tab\tab ; clear the ram we pointed to\par
\tab incf FSR,f\tab\tab\tab ; inc pointer to next ram byte\par
\tab movf FSR,w\tab\tab\tab ; get copy of pointer to w\par
\tab sublw RAM_END\tab\tab\tab ; test if PAST the last byte now\par
\tab skpweq\tab\tab\tab\tab ;\par
\tab goto ram_clear_loop\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; here we can set the user variables and output pins\par
\par
\tab movlw 0x00\tab\tab\tab ; for step 0 of 0-71\par
\tab movwf step\tab\tab\tab ; loaded ready for jump table\par
\par
\tab movf PORTA,w\tab\tab\tab ; get initial value for inputs\par
\tab movwf inputs\tab\tab\tab ;\par
\tab movwf inputs_last\tab\tab ;\par
\par
\tab ;-------------------------------------------------\par
\tab\tab\tab\tab\tab\tab ; set up INTCON register last\par
\tab movlw b'00000000'\tab\tab ; set the bit value \par
\par
\tab\tab ;  x-------\tab\tab ; bit7 \tab GIE global int enable, 1=enabled\par
\tab\tab ;  -x------\tab\tab ; bit6\tab EE write complete enable, 1=en\par
\tab\tab ;  --x-----\tab\tab ; bit5 \tab TMR0 overflow int enable, 1=en\par
\tab\tab ;  ---x----\tab\tab ; bit4 \tab RB0/INT enable, 1=en\par
\tab\tab ;  ----x---\tab\tab ; bit3\tab RB port change int enable, 1=en\par
\tab\tab ;  -----x--\tab\tab ; bit2\tab TMR0 int flag bit, 1=did overflow and get int\par
\tab\tab ;  ------x-\tab\tab ; bit1\tab RB0/INT flag bit, 1=did get int\par
\tab\tab ;  -------x\tab\tab ; bit0\tab RB port int flag bit, 1=did get int\par
\par
\tab movwf INTCON\tab\tab\tab ; put in INTCON register\par
\tab ;-------------------------------------------------\par
\tab return\tab\tab\tab\tab ;\par
;------------------------------------------------------------------------------\par
\par
\par
\par
\par
\par
;==============================================================================\par
\tab ; this code is only to display 1k of the memory usage chart\par
\tab ; in the absolute listing!\par
\par
\tab ; page 0 256 byte block--------------------\par
\tab ;org 0x40-2\par
\tab ;nop\par
\tab ;org 0x80-1\par
\tab ;nop\par
\tab ;org 0xC0-1\par
\tab ;nop\par
\tab ;org 0x100-1\par
\tab ;nop\par
\par
\tab ; page 1 256 byte block--------------------\par
\tab ;org 0x140-2\par
\tab ;nop\par
\tab ;org 0x180-1\par
\tab ;nop\par
\tab ;org 0x1C0-1\par
\tab ;nop\par
\tab ;org 0x200-1\par
\tab ;nop\par
\par
\tab ; page 2 256 byte block--------------------\par
\tab org 0x240-2\par
\tab nop\par
\tab org 0x280-1\par
\tab nop\par
\tab org 0x2C0-1\par
\tab nop\par
\tab org 0x300-1\par
\tab nop\par
\par
\tab ; page 3 256 byte block--------------------\par
\tab org 0x340-2\par
\tab nop\par
\tab org 0x380-1\par
\tab nop\par
\tab org 0x3C0-1\par
\tab nop\par
\tab org 0x400-1\par
\tab nop\par
\par
\par
\tab IFDEF __16F628A\par
\tab\tab ; page 4 256 byte block--------------------\par
\tab\tab org 0x440-2\par
\tab\tab nop\par
\tab\tab org 0x480-1\par
\tab\tab nop\par
\tab\tab org 0x4C0-1\par
\tab\tab nop\par
\tab\tab org 0x500-1\par
\tab\tab nop\par
\par
\tab\tab ; page 5 256 byte block--------------------\par
\tab\tab org 0x540-2\par
\tab\tab nop\par
\tab\tab org 0x580-1\par
\tab\tab nop\par
\tab\tab org 0x5C0-1\par
\tab\tab nop\par
\tab\tab org 0x600-1\par
\tab\tab nop\par
\par
\tab\tab ; page 6 256 byte block--------------------\par
\tab\tab org 0x640-2\par
\tab\tab nop\par
\tab\tab org 0x680-1\par
\tab\tab nop\par
\tab\tab org 0x6C0-1\par
\tab\tab nop\par
\tab\tab org 0x700-1\par
\tab\tab nop\par
\par
\tab\tab ; page 7 256 byte block--------------------\par
\tab\tab org 0x740-2\par
\tab\tab nop\par
\tab\tab org 0x780-1\par
\tab\tab nop\par
\tab\tab org 0x7C0-1\par
\tab\tab nop\par
\tab\tab org 0x800-1\par
\tab\tab nop\par
\tab ENDIF\par
\par
\tab ;-------------------------------------------------------------------------\par
\tab end\par
\tab ;-------------------------------------------------------------------------\par
\par
;==============================================================================\par
;==============================================================================\par
;==============================================================================\par
\par
\par
\par
\tab ;-------------------------------------------------\par
\tab ; NOTE!! example! below is the original (non-pwm) table for the\par
\tab ; 24x hardware 6th steps.\par
\tab ; this will be useful to code a minimum-rom microstepper\par
\tab ; if you don't need 3600 and can make do with 1200 steps.\par
\par
\tab ; same system as the main code;\par
\tab ; ----xxxx\tab are the phase sequencing\par
\tab ; xxxx----\tab are the current values\par
\par
\tab ; (this code table has been used and tested!)\par
\tab ;-------------------------------------------------\par
\tab ; COMMENTED OUT!\par
\par
\tab\tab ;movlw b'11000101'\tab\tab ; 0,\tab\tab 100,0 \tab A+ B+\tab 00=0\tab\tab 01=25\par
\tab\tab ;movlw b'11010101'\tab\tab ; 1,\tab\tab 100,25\tab A+ B+\tab 10=55\tab 11=100\par
\tab\tab ;movlw b'11100101'\tab\tab ; 2, \tab 100,55 \tab A+ B+\par
\tab\tab ;movlw b'11110101'\tab\tab ; 3, \tab 100,100\tab A+ B+\par
\tab\tab ;movlw b'10110101'\tab\tab ; 4, \tab 55,100\tab A+ B+\par
\tab\tab ;movlw b'01110101'\tab\tab ; 5, \tab 25,100\tab A+ B+\par
\tab ;-------------------------\par
\tab\tab ;movlw b'00111001'\tab\tab ; 6, \tab 0,100\tab A- B+\par
\tab\tab ;movlw b'01111001'\tab\tab ; 7, \tab 25,100\tab A- B+\par
\tab\tab ;movlw b'10111001'\tab\tab ; 8, \tab 55,100\tab A- B+\par
\tab\tab ;movlw b'11111001'\tab\tab ; 9, \tab 100,100\tab A- B+\par
\tab\tab ;movlw b'11101001'\tab\tab ; 10, \tab 100,55\tab A- B+\par
\tab\tab ;movlw b'11011001'\tab\tab ; 11, \tab 100,25\tab A- B+\par
\tab ;-------------------------\par
\tab\tab ;movlw b'11001010'\tab\tab ; 12, \tab 100,0\tab A- B-\par
\tab\tab ;movlw b'11011010'\tab\tab ; 13, \tab 100,25\tab A- B-\par
\tab\tab ;movlw b'11101010'\tab\tab ; 14, \tab 100,55\tab A- B-\par
\tab\tab ;movlw b'11111010'\tab\tab ; 15, \tab 100,100\tab A- B-\par
\tab\tab ;movlw b'10111010'\tab\tab ; 16, \tab 55,100\tab A- B-\par
\tab\tab ;movlw b'01111010'\tab\tab ; 17, \tab 25,100\tab A- B-\par
\tab ;-------------------------\par
\tab\tab ;movlw b'00110110'\tab\tab ; 18, \tab 0,100\tab A+ B-\par
\tab\tab ;movlw b'01110110'\tab\tab ; 19, \tab 25,100\tab A+ B-\par
\tab\tab ;movlw b'10110110'\tab\tab ; 20, \tab 55,100\tab A+ B-\par
\tab\tab ;movlw b'11110110'\tab\tab ; 21, \tab 100,100\tab A+ B-\par
\tab\tab ;movlw b'11100110'\tab\tab ; 22, \tab 100,55\tab A+ B-\par
\tab\tab ;movlw b'11010110'\tab\tab ; 23, \tab 100,25\tab A+ B-\par
\par
\par
\par
\tab EXAMPLE! full table example here, 0-71 steps showing every step...\par
\par
\tab ;-------------------------\par
\tab 0\tab 100,0 \tab A+ B+\par
\tab 1\tab  100,8   (pwm tween)\par
\tab 2\tab  100,17  (pwm tween)\par
\tab 3\tab 100,25\tab A+ B+\par
\tab 4\tab  100,35  (pwm tween)\par
\tab 5\tab  100,45  (pwm tween)\par
\tab 6\tab 100,55 \tab A+ B+\par
\tab 7\tab  100,70  (pwm tween)\tab\par
\tab 8\tab  100,85  (pwm tween)\par
\tab 9\tab 100,100\tab A+ B+\tab (rest of table is same, tweens not shown)\par
\tab 10\par
\tab 11\par
\tab 12\tab 55,100\tab A+ B+\par
\tab 13\par
\tab 14\par
\tab 15\tab 25,100\tab A+ B+\par
\tab 16\par
\tab 17\par
\tab ;-------------------------\par
\tab 18\tab 0,100\tab A- B+\par
\tab 19\par
\tab 20\par
\tab 21\tab 25,100\tab A- B+\par
\tab 22\par
\tab 23\par
\tab 24\tab 55,100\tab A- B+\par
\tab 25\par
\tab 26\par
\tab 27\tab 100,100\tab A- B+\par
\tab 28\par
\tab 29\par
\tab 30\tab 100,55\tab A- B+\par
\tab 31\par
\tab 32\par
\tab 33\tab 100,25\tab A- B+\par
\tab 34\par
\tab 35\par
\tab ;-------------------------\par
\tab 36\tab 100,0\tab A- B-\par
\tab 37\par
\tab 38\par
\tab 39\tab 100,25\tab A- B-\par
\tab 40\par
\tab 41\par
\tab 42\tab 100,55\tab A- B-\par
\tab 43\par
\tab 44\par
\tab 45\tab 100,100\tab A- B-\par
\tab 46\par
\tab 47\par
\tab 48\tab 55,100\tab A- B-\par
\tab 49\par
\tab 50\par
\tab 51\tab 25,100\tab A- B-\par
\tab 52\par
\tab 53\par
\tab ;-------------------------\par
\tab 54\tab 0,100\tab A+ B-\par
\tab 55\par
\tab 56\par
\tab 57\tab 25,100\tab A+ B-\par
\tab 58\par
\tab 59\par
\tab 60\tab 55,100\tab A+ B-\par
\tab 61\par
\tab 62\par
\tab 63\tab 100,100\tab A+ B-\par
\tab 64\par
\tab 65\par
\tab 66\tab 100,55\tab A+ B-\par
\tab 67\par
\tab 68\par
\tab 69\tab 100,25\tab A+ B-\par
\tab 70\par
\tab 71\par
\tab ;-------------------------------------------------\par
\tab\par
\par
\par
\par
file: /Techref/io/stepper/linistep/Lini_asm_v21.asm, 36KB, , updated: 2011/4/6 14:29, local time: 2012/8/7 07:50,\par
TOP NEW MORE HELP FIND: \par
212.226.74.38:LOG IN\par
\'a92012 PLEASE DON'T RIP! DO: LINK / DIGG! / MAKE!\par
 \tab\'a92012 These pages are served without commercial sponsorship. (No popup ads, etc...).Bandwidth abuse increases hosting cost forcing sponsorship or shutdown. This server aggressively defends against automated copying for any reason including offline viewing, duplication, etc... Please respect this requirement and DO NOT RIP THIS SITE. Questions?\par
Please DO link to this page! Digg it! / MAKE! / \par
\par
<A HREF="http://www.piclist.com/techref/io/stepper/linistep/Lini_asm_v21.asm"> io stepper linistep Lini_asm_v21</A>\par
Did you find what you needed? From: "/io/stepper/linistep/index.htm"\par
\par
    "Not quite. Look for more pages like this one."\par
    "No. I'm looking for: "\par
    "No. Take me to the search page."\par
    "No. Take me to the top so I can drill down by catagory"\par
    "No. I'm willing to pay for help, please refer me to a qualified consultant" \par
\par
 \tab\par
Stepper motors CAN be smooth!\par
And stepper controllers can be strong and cheap. Roman Black's Linistep stepper controller kits:\par
o 18th microstep\par
o Linear smoothing \tab   \tab o Open source\par
o Full kit $25!\par
 \tab\par
Quick, Easy and CHEAP! RCL-1 RS232 Level Converter in a DB9 backshell\par
Ashley Roll has put together a really nice little unit here. Leave off the MAX232 and keep these handy for the few times you need true RS232!\par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
 \par
\par
  . \par
}
 