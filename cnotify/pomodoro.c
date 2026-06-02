#include "pomodoro.h"
#include "timer.h"
#include "notify.h"
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static volatile sig_atomic_t global_stop = 0;

static void pomodoro_sig_handler(int sig)
{
    (void)sig;
    global_stop = 1;
    timer_cancel();
}

int pomodoro_run(int work_min, int break_min, bool quiet)
{
    int work_sec = work_min * 60;
    int break_sec = break_min * 60;
    int cycle = 0;

    /* Catch Ctrl-C / SIGTERM to stop gracefully */
    signal(SIGINT, pomodoro_sig_handler);
    signal(SIGTERM, pomodoro_sig_handler);

    if (!quiet) {
        printf("🍅 Pomodoro started: %dmin work / %dmin break\n", work_min, break_min);
        printf("   Press Ctrl+C to stop\n\n");
    }

    while (!global_stop) {
        cycle++;

        /* Work phase */
        if (!quiet) printf("🍅 Cycle %d — WORK %dmin\n", cycle, work_min);
        notify_send("🍅 Pomodoro", "Work phase started");

        timer_start(work_sec);
        if (global_stop || timer_is_active() == 0) break;

        if (!quiet) printf("   Work done ✓\n");
        notify_send("🍅 Pomodoro", "Work phase finished — take a break!");

        if (global_stop) break;

        /* Break phase */
        if (!quiet) printf("☕ Cycle %d — BREAK %dmin\n", cycle, break_min);
        notify_send("☕ Pomodoro", "Break time");

        timer_start(break_sec);
        if (global_stop || timer_is_active() == 0) break;

        if (!quiet) printf("   Break done ✓\n\n");
        notify_send("🍅 Pomodoro", "Break finished — back to work!");

        /* Guard against infinite rapid cycles */
        if (global_stop) break;
    }

    if (!quiet) {
        printf("\n🍅 Pomodoro stopped after %d cycles.\n", cycle);
    }

    notify_send("🍅 Pomodoro", "Pomodoro stopped");

    return 0;
}
