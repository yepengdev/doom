#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>
#include <stdbool.h>

/* Start a countdown of `seconds`. Returns 0 on success, -1 on error. */
int timer_start(int seconds);

/* Block until the timer fires (returns seconds elapsed) or is cancelled.
   Returns remaining seconds (0 = fired, >0 = cancelled mid-way). */
int timer_wait(void);

/* Cancel a running timer from another thread / signal handler. */
void timer_cancel(void);

/* Check if timer is currently active. */
bool timer_is_active(void);

/* Get elapsed seconds since timer_start was called. */
int timer_elapsed(void);

#endif
