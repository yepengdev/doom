#include "timer.h"
#include <time.h>
#include <signal.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

static volatile sig_atomic_t timer_cancelled = 0;
static time_t timer_start_ts = 0;

int timer_start(int seconds)
{
    struct itimerspec its;
    timer_t timerid;

    /* Use a POSIX timer instead of timerfd for broader compatibility */
    struct sigevent sev = {0};
    sev.sigev_notify = SIGEV_NONE;  /* we'll block on it */

    if (timer_create(CLOCK_MONOTONIC, &sev, &timerid) != 0) {
        fprintf(stderr, "timer_create: %s\n", strerror(errno));
        return -1;
    }

    its.it_value.tv_sec = seconds;
    its.it_value.tv_nsec = 0;
    its.it_interval.tv_sec = 0;
    its.it_interval.tv_nsec = 0;

    if (timer_settime(timerid, 0, &its, NULL) != 0) {
        fprintf(stderr, "timer_settime: %s\n", strerror(errno));
        return -1;
    }

    /* Store for elapsed calculations */
    timer_start_ts = time(NULL);

    /* Block until timer fires */
    while (1) {
        if (timer_gettime(timerid, &its) != 0) break;
        if (its.it_value.tv_sec == 0 && its.it_value.tv_nsec == 0)
            break;  /* timer fired */

        /* Sleep and check for cancellation */
        struct timespec ts = { .tv_sec = 0, .tv_nsec = 50000000 }; /* 50ms */
        nanosleep(&ts, NULL);

        if (timer_cancelled) {
            timer_delete(timerid);
            return time(NULL) - timer_start_ts;  /* return elapsed */
        }
    }

    timer_delete(timerid);
    return 0;  /* fired normally */
}

int timer_wait(void)
{
    /* timer_start already blocks, so this is a no-op */
    return 0;
}

void timer_cancel(void)
{
    timer_cancelled = 1;
}

bool timer_is_active(void)
{
    return timer_start_ts > 0 && !timer_cancelled;
}

int timer_elapsed(void)
{
    if (timer_start_ts == 0) return 0;
    return (int)(time(NULL) - timer_start_ts);
}
