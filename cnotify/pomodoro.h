#ifndef POMODORO_H
#define POMODORO_H

#include <stdbool.h>

/* Run pomodoro cycle: work_min of focus, break_min of rest, looping until
   SIGINT/SIGTERM. Returns exit code. */
int pomodoro_run(int work_min, int break_min, bool quiet);

#endif
