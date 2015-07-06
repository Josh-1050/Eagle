/*
 * main.c
 *
 *  Created on: 3.5.2009
 *      Author: Administrator
 */



#include <avr/io.h>
#include <avr/interrupt.h>
#include "bitmacro.h"
#include <util/delay.h>

#define A 1
#define A_ 2
#define B 4
#define B_ 8

#define STEP1 A
#define STEP2 B_
#define STEP3 B
#define STEP4 A_

#define STEP_PIN 3
#define DIR_PIN 4

#define LED1_PIN 1
#define LED2_PIN 2



volatile int8_t counter;
volatile int8_t no_steps;

uint8_t step_normal[] ={A,B,A_,B_};
uint8_t step_normal_full[]={A+B_,A+B,A_+B,A_+B_};
uint8_t step_half[]={A,A+B,B,B+A_,A_,A_+B_,B_,B_+A};

ISR(PCINT2_vect){


	if(CHECKBIT(PIND,STEP_PIN)){

		if(CHECKBIT(PIND,DIR_PIN)){
			counter++;
			if(counter > no_steps) counter=0;
		}

		else{
			counter--;
			if(counter<0) counter = no_steps;
		}

	}

}

void full_step(){
	while(1){

		//TODO enable pin

			if(!CHECKBIT(PINB,5)){

				PORTC = PORTC | (3 & step_normal[counter]); //outputs A, A_
				PORTC = PORTC & (3 | step_normal[counter]);
			}
			else{
				PORTC = PORTC & 252;
			}

			if(!CHECKBIT(PINC,5)){

				PORTC = PORTC | (12 & step_normal[counter]); //outputs B, B_
				PORTC = PORTC & (12 | step_normal[counter]);
			}
			else{
				PORTC = PORTC & 243;
			}

		}
}

void half_step(){
	while(1){

		//TODO enable pin

			if(!CHECKBIT(PINB,5)){

				PORTC = PORTC | (3 & step_half[counter]); //outputs A, A_
				PORTC = PORTC & (3 | step_half[counter]);
			}
			else{
				PORTC = PORTC & 252;
			}

			if(!CHECKBIT(PINC,5)){

				PORTC = PORTC | (12 & step_half[counter]); //outputs B, B_
				PORTC = PORTC & (12 | step_half[counter]);
			}
			else{
				PORTC = PORTC & 243;
			}

		}
}

int main() {

	counter = 0;
	DDRC = 15;
	DDRD = 6;

	//configure interrupts for STEP
	PCICR |= (1<<PCIE2);
	PCMSK2 |= (1<<PCINT19);

	sei();

	no_steps = 7;


	half_step();

	}

/*
	//DDRB = 0x00;
	DDRD = 0xff;
	DDRC = 0x00;
	counter = 1;
	PORTD = 1;
	//GIMSK |=  (1<<PCINT0);
	//EICRA |= (1<<ISC11) | (1<<ISC10);
	//EIMSK |=(1<<INT1);

	PCICR |= (1<<PCIE0);
	PCMSK0 =0xff;

	sei();

	//while(1);
	while(1){
		if(CHECKBIT(PINC,0)) PORTD = 0;
		else PORTD = step_normal[counter];
	}*/




