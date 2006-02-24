#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <getopt.h>
#include <time.h>

// ADJUSTABLE PARAMETERS
float crowding_penalty = 0.1;
float double_meeting_penalty = 100.0;
float shared_major_prof_penalty = 10.0;

#define HELP_MSG "\nUsage: %s [OPTIONS]\nSolve constrained schedule-optimization problem.\n\nOptions:\n\t[-t, -ntries=<arg>]\tset number of trials to <arg> (default=100)\n\t[-n, --nrand=<arg>]\tdo <arg> optimization steps per trial (default=5000)\n\t[-b, --nbest=<arg>]\tsave the <arg> best schedules (default=1)\n\t[-q, --quiet]\t\tsuppress progress information\n\t[-c, --curves]\t\tprint intermediate optimalities to stdout (for diagnostic purposes)\n\t[-i, --input=<arg>]\tget input from file <arg> (default=stdin)\n\t[-o, --output <arg>]\twrite output to file <arg>.csv\n\t[-H, --help]\t\tprint this message\n\nInput must be in a particular form.  The related program visparse will read a CSV file and write the data in the form needed by %s to stdout.  Thus the command\n\t'visparse <CSV file> | %s [OPTIONS]'\nwill solve the scheduling problem.\n\n"

typedef struct {
  unsigned long len;
  int *data;
} int_vector_t;

typedef struct {
  int nprof, ntime, nstudent;
  char **profs, **times, **students;
  int_vector_t *openings;
  long prod;
  float *weights;
} spec_t;

typedef struct {
  unsigned long nstud, nprof, ntime;
  unsigned long size, dp, ds;
  char *data;
} schedule_t;

int verbosity=2;
int show_curves=0;

void free_specs(spec_t *);
spec_t *read_specs(FILE *);
schedule_t *newschedule(spec_t *);
void freeschedule(schedule_t *);
char slot(schedule_t *, int, int, int);
char *sslot(schedule_t *, int, int, int);
float weight(spec_t *, int, int);
float benefit(schedule_t *, spec_t *);
void random_schedule(schedule_t *, spec_t *);
float optimize(schedule_t *, spec_t *, int);
void write_csv_file (FILE *, spec_t *, int, float, schedule_t *);

int main (int argc, char **argv)
{
  int opt;
  int ntries = 100, nbest = 1, nrand = 5000;
  FILE *data = stdin;
  int fileout = 0;
  char *outfile="sched";
  time_t t1, t2;

  t1 = time(0);
  srand48((long) t1);

  while (1) {
    int option_index = 0;
    static struct option long_options[] = {
      {"ntries",1,0,'t'},
      {"nrand",1,0,'n'},
      {"nbest",1,0,'b'},
      {"quiet",0,0,'q'},
      {"curves",0,0,'c'},
      {"input",1,0,'i'},
      {"output",1,0,'o'},
      {"help",0,0,'H'},
      {0,0,0,0}
    };

    opt = getopt_long (argc, argv, "cqt:n:b:i:o:H", long_options, &option_index);
    if (opt == -1) break;

    switch (opt) {
    case 't':
      sscanf(optarg, "%d", &ntries);
      break;
    case 'n':
      sscanf(optarg, "%d", &nrand);
      break;
    case 'b':
      sscanf(optarg, "%d", &nbest);
      break;
    case 'q':
      verbosity--;
      break;
    case 'c':
      show_curves = 1;
      break;
    case 'o':
      outfile = optarg;
      fileout = 1;
      break;
    case 'i':
      if ((data = fopen(optarg, "r")) == NULL) {
	perror("reading data file");
	return 0;
      }
      break;
    case 'H':
    case '?':
    default:
      fprintf(stderr, HELP_MSG, argv[0], argv[0], argv[0]);
      exit(1);
      break;
    }
  }

  {
    spec_t *specs;
    schedule_t **best, *current;
    float *goodness, gmin, g;
    int j, k, kmin;

    if (verbosity > 1) {
      t1 = time(0);
      fprintf(stderr, "\n");
    }

    specs = read_specs(data);
    fclose(data);

    if (verbosity > 1) fprintf(stderr, "#");

    best = (schedule_t **) malloc(nbest * sizeof(schedule_t *));
    goodness = (float *) malloc(nbest * sizeof(float));

    for (k = 0; k < nbest; k++) {
      best[k] = current = newschedule(specs);
      random_schedule(current, specs);
      goodness[k] = benefit(current, specs);
    }

    if (verbosity > 1) fprintf(stderr, "#");

    current = newschedule(specs);
    random_schedule(current, specs);

    if (verbosity > 1) 
      fprintf(stderr, "##############################");

    for (j = 0; j < ntries; j++) {

      for (k = 1, kmin = 0, gmin = goodness[0]; k < nbest; k++)
	if (gmin > goodness[k]) {
	  gmin = goodness[k];
	  kmin = k;
	}

      // optimization loop
      random_schedule(current, specs);
      g = optimize(current, specs, nrand);
      if (g > gmin) {
	free(best[kmin]);
	best[kmin] = current;
	goodness[kmin] = g;
	if (ntries - j > 1) {
	  current = newschedule(specs);
	}
      }
      if (verbosity > 1)
	if ( (j % (ntries/100+1)) == 0 ) {
	  int p = 100*j/ntries;
	  fprintf(stderr, "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b % 5d%% completed #######", p);
	} 
    }

    if (verbosity > 1)
      fprintf(stderr, "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b % 5d%% completed #######\n", 100);

    for (j = nbest-1; j >= 0; j--) {
      for (k = 0, kmin = 0, gmin = goodness[0]; k <= j; k++)
	if (gmin > goodness[k]) {
	  gmin = goodness[k];
	  kmin = k;
	}
      g = goodness[j];
      goodness[j] = gmin;
      goodness[kmin] = g;
      current = best[j];
      best[j] = best[kmin];
      best[kmin] = current;
    }

    if (verbosity > 0) 
      fprintf(stderr, "%s results\n", argv[0]);

    if (fileout) {
      char fname[BUFSIZ];
      sprintf(fname, "%s.csv", outfile);
      if (!(data = fopen(fname, "w"))) {
	  fprintf(stderr, "error opening file %s\n", fname);
	  perror("main");
	  exit(-1);
      }
    } else {
      data = stdout;
    }
    for (k = 0; k < nbest; k++) {
      write_csv_file(data, specs, k+1, goodness[k], best[k]);
    }
    fclose(data);

    if (verbosity > 1) {
      t2 = time(0);
	fprintf(stderr, "%d trials, %d steps/trial, elapsed time: %ld sec\n", ntries, nrand, ((long) (t2 - t1)));
    }

    for (k = 0; k < nbest; k++) free(best[k]);
    free(best);
    free(goodness);
    free_specs(specs);
  }

  return 0;
}

void free_specs (spec_t *s)
{
  int k;
  free(s->profs[0]);
  free(s->profs);
  free(s->times);
  free(s->students);
  for (k = 0; k < s->ntime; k++)
    free(s->openings[k].data);
  free(s->openings);
  free(s->weights);
  free(s);
}

spec_t *read_specs (FILE *f)
{

  int j, k;
  unsigned long len, namebuffersize = 0;
  char *pos, *namebuffer = 0;
  spec_t *s;
  
  s = (spec_t *) malloc(sizeof(spec_t));

  fscanf(f, "%d %d %d\n", &(s->nprof), &(s->ntime), &(s->nstudent));

  s->profs = (char **) malloc(s->nprof * sizeof(char *));
  s->times = (char **) malloc(s->ntime * sizeof(char *));
  s->students = (char **) malloc(s->nstudent * sizeof(char *));

  namebuffersize = (s->nprof + s->ntime + s->nstudent) * BUFSIZ;
  pos = namebuffer = (char *) malloc(namebuffersize * sizeof(char *));
  len = 0;

  for (k = 0; k < s->nprof; k++) {
    s->profs[k] = pos = namebuffer + len;
    fgets(pos, namebuffersize - len, f);
    len += strlen(pos);
    while (*pos != '\0') {
      if (*pos == '\n') *pos = '\0';
      ++pos;
    }
  }

  for (k = 0; k < s->ntime; k++) {
    s->times[k] = pos = namebuffer + len;
    fgets(pos, namebuffersize - len, f);
    len += strlen(pos);
    while (*pos != '\0') {
      if (*pos == '\n') *pos = '\0';
      ++pos;
    }
  }

  for (k = 0; k < s->nstudent; k++) {
    s->students[k] = pos = namebuffer + len;
    fgets(pos, namebuffersize - len, f);
    len += strlen(pos);
    while (*pos != '\0') {
      if (*pos == '\n') *pos = '\0';
      ++pos;
    }
  }

  namebuffer = (char *) realloc(namebuffer, len * sizeof(char));

  s->openings = (int_vector_t *) malloc(s->ntime * sizeof(int_vector_t));
  s->prod = 1;
  for (k = 0; k < s->ntime; k++) {
    fscanf(f, "%lu", &(s->openings[k].len));
    if (s->openings[k].len < 1) {
      fprintf(stderr, "no openings in %s time slot\n", s->times[k]);
      exit(-1);
    }
    s->prod *= s->openings[k].len;
    s->openings[k].data = (int *) malloc(s->openings[k].len * sizeof(int));
    for (j = 0; j < s->openings[k].len; j++) {
      fscanf(f, "%d", &(s->openings[k].data[j]));
    }
  }


  s->weights = (float *) malloc(s->nstudent * s->nprof * sizeof(float));

  for (k = 0; k < s->nstudent; k++) {
    for (j = 0; j < s->nprof; j++) {
      fscanf(f, "%f", &(s->weights[j * s->nstudent + k]));
    }
  }

//   for (k = 0; k < s->nprof; k++)
//     printf("%s\n", s->profs[k]);
//   for (k = 0; k < s->nstudent; k++) {
//     printf("%s:", s->students[k]);
//     for (j = 0; j < s->nprof; j++) {
//       printf("\t% 0.2f", s->weights[j*s->nstudent + k]);
//     }
//     printf("\n");
//   }

//   for (k = 0; k < s->ntime; k++) {
//     printf("%s: ", s->times[k]);
//     for (j = 0; j < s->openings[k].len; j++) {
//       printf("\t%s", s->profs[s->openings[k].data[j]]);
//     }
//     printf("\n");
//   }

  return s;
}

schedule_t *newschedule (spec_t *s)
{
  schedule_t *x;
  x = (schedule_t *) malloc(sizeof(schedule_t));
  x->nprof = s->nprof;
  x->nstud = s->nstudent;
  x->ntime = s->ntime;
  x->size = s->nprof * s->nstudent * s->ntime;
  x->dp = s->nstudent * s->ntime;
  x->ds = s->ntime;
  x->data = (char *) malloc(x->size*sizeof(char));
  return x;
}

void freeschedule (schedule_t *x)
{
  free(x->data);
  free(x);
}

char slot (schedule_t *x, int p, int s, int t)
{
  return x->data[x->dp * p + x->ds * s + t];
}

char *sslot (schedule_t *x, int p, int s, int t)
{
  return &x->data[x->dp * p + x->ds * s + t];
}

float weight (spec_t *x, int p, int s)
{
  return x->weights[p * x->nstudent + s];
}

float benefit (schedule_t *x, spec_t *y)
{
  float b = 0.0, penalty, n;
  int p, s, t, ss;

  // sum up weights of scheduled visits.
  for (p = 0; p < x->nprof; p++)
    for (s = 0; s < x->nstud; s++) {
      n = weight(y,p,s);
      for (t = 0; t < x->ntime; t++)
	b += ((float) slot(x,p,s,t)) * n;
    }

  // meetings are better one-on-one
  for (p = 0, penalty = 0.0; p < x->nprof; p++)
    for (t = 0; t < x->ntime; t++) {
      for (s = 0, n = -1.0; s < x->nstud; s++)
	n += ((float) slot(x,p,s,t));
      penalty += (n > 0.0) ? (n * n) : 0.0;
    }
  b -= crowding_penalty * penalty;

  // better not to meet twice with one professor
  for (s = 0, penalty = 0.0; s < x->nstud; s++)
    for (p = 0; p < x->nprof; p++) {
      for (t = 0, n = -1.0; t < x->ntime; t++)
	n += ((float) slot(x,p,s,t));
      penalty += (n > 0.0) ? (n * n) : 0.0;
    }
  b -= double_meeting_penalty * penalty;

  // each student should meet with major professor alone
  for (s = 0, penalty = 0.0; s < x->nstud; s++)
    for (p = 0; p < x->nprof; p++)
      if (weight(y,p,s) >= 1.0) {
	for (t = 0, n = -1.0; t < x->ntime; t++) {
	  if (slot(x,p,s,t)) {
	    for (ss = 0; ss < x->nstud; ss++)
	      n += ((float) slot(x,p,ss,t));
	  }
	}
	penalty += (n * n);
      }
  b -= shared_major_prof_penalty * penalty;

  return b;
}

void random_schedule (schedule_t *x, spec_t *y)
{
  long r;
  int s, t, k, p;
  
  // zero out the schedule matrix
  for (p = 0; p < x->nprof; p++)
    for (s = 0; s < x->nstud; s++)
      for (t = 0; t < x->ntime; t++)
	*(sslot(x,p,s,t)) = 0;

  // assign each student a random itinerary
  for (s = 0; s < x->nstud; s++) {
    r = (long) floor(drand48() * y->prod);
    for (t = 0; t < x->ntime; t++) {
      k = r % (y->openings[t].len);
      r = r / (y->openings[t].len);
      p = y->openings[t].data[k];
      *(sslot(x,p,s,t)) = 1;
    }	 
  }
}

float optimize (schedule_t *x, spec_t *y, int n)
{
  float g, gg;
  long r;
  int k, p = -1, pp, q, s, t;

  g = benefit(x, y);

  for (k = 0; k < n; k++) {
    // pick a random student and time
    r = (long) floor(drand48() * x->nstud * x->ntime);
    s = r % x->nstud;
    t = r / x->nstud;
    // delete existing appointment
    for (q = 0; q < x->nprof; q++) {
      if (slot(x,q,s,t)) {
	p = q;
	*(sslot(x,q,s,t)) = 0;
      }
    }
    if (p < 0) {
      fprintf(stderr, "this shouldn't ever happen\n");
      exit(-1);
    }
    // pick a random professor from those open and schedule appointment
    r = (long) floor(drand48() * y->openings[t].len);
    pp = y->openings[t].data[r];
    *(sslot(x,pp,s,t)) = 1;
    //    fprintf(stderr, "(%d %d %d %d)", s, t, p, pp);

    gg = benefit(x, y);
    if (gg < g) {
      *(sslot(x,pp,s,t)) = 0;
      *(sslot(x,p,s,t))  = 1;
    } else {
      g = gg;
    }
    if (show_curves) printf("%d %f\n", k, g);
  }

  if (show_curves) printf("\n");

  return g;
}

void write_csv_file (FILE *f, spec_t *y, int option, float goodness, schedule_t *x)
{
  int p, s, t, n, m;
  int v[BUFSIZ];

  fprintf(f, "Option %d, goodness %f\n", option, goodness);
  fprintf(f, "Student schedules\n");
  fprintf(f, "Student");
  for (t = 0; t < y->ntime; t++)
    fprintf(f, ", %s", y->times[t]);
  fprintf(f, ", Missing, Extra\n");

  for (s = 0; s < y->nstudent; s++) {
    fprintf(f, "%s", y->students[s]);

    // appointments
    for (t = 0; t < y->ntime; t++) {
      for (p = 0; p < y->nprof; p++) {
	if (slot(x,p,s,t)) {
	  fprintf(f, ", %s", y->profs[p]);
	}
      }
    }

    // missing
    for (p = y->nprof-1, n = 0; p >= 0; p--) {
      if (weight(y,p,s)) {
	for (t = 0, m = 1; t < y->ntime; t++)
	  if (slot(x,p,s,t)) {
	    m = 0;
	    break;
	  }
	if (m) v[n++] = p;
      }
    }
    fprintf(f, ", ");
    if (n > 0) {
      while (n-- > 1) {
	fprintf(f, "%s/", y->profs[v[n]]);
      }
      fprintf(f, "%s", y->profs[v[n]]);
    }

    // extras
    for (p = y->nprof-1, n = 0; p >= 0; p--) {
      if (!(weight(y,p,s))) {
	for (t = 0, m = 0; t < y->ntime; t++)
	  if (slot(x,p,s,t)) {
	    m = 1;
	    break;
	  }
	if (m) v[n++] = p;
      }
    }
    fprintf(f, ", ");
    if (n > 0) {
      while (n-- > 1) {
	fprintf(f, "%s/", y->profs[v[n]]);
      }
      fprintf(f, "%s", y->profs[v[n]]);
    }

    fprintf(f, "\n");
  }

  fprintf(f, "Professor schedules\n");
  fprintf(f, "Professor");
  for (t = 0; t < y->ntime; t++)
    fprintf(f, ", %s", y->times[t]);
  fprintf(f, "\n");

  for (p = 0; p < y->nprof; p++) {
    fprintf(f, "%s", y->profs[p]);
    for (t = 0; t < y->ntime; t++) {
      for (s = y->nstudent-1, n = 0; s >= 0; s--) {
	if (slot(x,p,s,t))
	  v[n++] = s;
      }
      fprintf(f, ", ");
      if (n > 0) {
	while (n-- > 1) {
	  fprintf(f, "%s/", y->students[v[n]]);
	}
	fprintf(f, "%s", y->students[v[n]]);
      }
    }
    fprintf(f, "\n");
  }
}
