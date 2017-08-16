# vissched: Visit-Day Scheduler

## Description

This tool uses simulated annealing for solving a complicated scheduling problem.
It is assumed that $M$ visitors wish to meet with $N$ residents.
There are $K$ time-slots available.
Each resident may or may not be available during any given time-slot.
Each visitor wishes to meet with a different subset of residents but does not care in which order the meetings are to be held.
Each visitor attaches a degree of importance, or weight, to each resident, indicative of the desire the visitor has to meet with the resident.
Thus a weight of 1 indicates a very strong desire, a weight of 0.5 a somewhat less-strong desire, and a weight of 0, complete indifference.

The algorithm attempts to find a schedule such that
(1) every visitor is meeting with someone during every time-slot,
(2) every visitor meets with every resident to which they have attached a weight of 1, and
(3) very few meetings are scheduled where more than one visitor meets with a resident at one time.
This is accomplished by assigning a measure of desirability, "goodness", to each possible schedule and then maximizing the goodness over the space of possible schedules by means of simulated annealing.

## Installation

Do
```
make
make INSTALLDIR=<dir> install
```
where `<dir>` is a webserver-accessible location.

## Detailed compilation instructions

To compile the program, you must compile the C code "vissched.c".
If you have gcc, for example, execute
```
gcc -O4 vissched.c -lm -o vissched
```
Note the linking with the math library via the "-lm" option.  The accompanying Makefile will accomplish this as well.

Execute
```
./vissched -H 
```
to get a message describing the various options.

The input must be in a rigidly-defined format.
Use the helper script "visparse.pl" to parse a CSV file into this format.
The accompanying CSV file "input.csv" is in the proper format for parsing by "visparse.pl".
You must have a working perl to use "visparse.pl".

Thus, for example, executing
```
perl visparse.pl input.csv | ./vissched --ntries=100 --nbest=3 --output=out
```
will result (after some time) in three CSV files, "out1.csv", "out2.csv", "out3.csv", which contain, respectively, the best, 2^nd^ best, and 3^rd^ best solutions found out of the 100 trials.

For details of the algorithm, which contains some adjustable parameters, consult the C code in file "vissched.c".
**Kindly direct questions, bug reports, and suggestions for improvements to the author, Aaron King <kingaa at umich dot edu>.**
