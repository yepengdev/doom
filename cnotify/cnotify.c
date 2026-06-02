#include "notify.h"
#include "timer.h"
#include "pomodoro.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <sys/types.h>
#include <errno.h>

static const char *pidfile = "/tmp/cnotify.pid";
static volatile sig_atomic_t running = 1;

static void daemon_sig_handler(int sig)
{
    (void)sig;
    running = 0;
    timer_cancel();
}

static int write_pid(void)
{
    FILE *f = fopen(pidfile, "w");
    if (!f) return -1;
    fprintf(f, "%d\n", getpid());
    fclose(f);
    return 0;
}

static int read_pid(void)
{
    FILE *f = fopen(pidfile, "r");
    if (!f) return -1;
    int pid;
    if (fscanf(f, "%d", &pid) != 1) { fclose(f); return -1; }
    fclose(f);
    return pid;
}

static void cmd_send(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: cnotify send <message>\n");
        exit(1);
    }
    notify_init_app();
    notify_send("cnotify", argv[1]);
    notify_cleanup();
}

static void cmd_timer(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: cnotify timer <seconds> [message]\n");
        exit(1);
    }

    int sec = atoi(argv[1]);
    if (sec <= 0) { fprintf(stderr, "Invalid seconds: %s\n", argv[1]); exit(1); }

    const char *msg = argc > 2 ? argv[2] : "Timer finished";

    notify_init_app();

    signal(SIGINT, daemon_sig_handler);
    signal(SIGTERM, daemon_sig_handler);

    write_pid();

    printf("⏱  Timer started: %d seconds\n", sec);

    int remaining = timer_start(sec);
    if (remaining == 0) {
        notify_send("⏱ Timer", msg);
        printf("⏱  Timer finished!\n");
    } else {
        printf("⏱  Timer cancelled after %d seconds\n", timer_elapsed());
    }

    notify_cleanup();
    unlink(pidfile);
}

static void cmd_pomodoro(int argc, char **argv)
{
    int work_min = 25, break_min = 5;
    bool quiet = false;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-w") == 0 && i + 1 < argc)
            work_min = atoi(argv[++i]);
        else if (strcmp(argv[i], "-b") == 0 && i + 1 < argc)
            break_min = atoi(argv[++i]);
        else if (strcmp(argv[i], "-q") == 0)
            quiet = true;
    }

    if (work_min <= 0 || break_min <= 0) {
        fprintf(stderr, "Invalid work/break minutes\n");
        exit(1);
    }

    notify_init_app();
    write_pid();
    pomodoro_run(work_min, break_min, quiet);
    notify_cleanup();
    unlink(pidfile);
}

static void cmd_status(void)
{
    pid_t pid = read_pid();
    if (pid < 0) {
        printf("cnotify: no running process\n");
        return;
    }
    if (kill(pid, 0) == 0) {
        printf("cnotify: running (PID %d)\n", pid);
    } else {
        printf("cnotify: stale PID file (PID %d not found)\n", pid);
        unlink(pidfile);
    }
}

static void cmd_stop(void)
{
    pid_t pid = read_pid();
    if (pid < 0) {
        printf("cnotify: no running process to stop\n");
        return;
    }
    if (kill(pid, SIGTERM) == 0) {
        printf("cnotify: sent SIGTERM to PID %d\n", pid);
    } else {
        fprintf(stderr, "cnotify: failed to stop PID %d: %s\n", pid, strerror(errno));
    }
}

static void print_usage(void)
{
    printf("Usage: cnotify <command> [options]\n\n"
           "Commands:\n"
           "  send <msg>              Send a desktop notification\n"
           "  timer <sec> [msg]       Countdown timer with notification\n"
           "  pomodoro [-w min] [-b min]  Pomodoro timer (default 25/5 min)\n"
           "  status                  Check if cnotify is running\n"
           "  stop                    Stop running cnotify process\n"
           "  help                    Show this help\n");
}

int main(int argc, char **argv)
{
    if (argc < 2) { print_usage(); return 1; }

    if (strcmp(argv[1], "send") == 0)
        cmd_send(argc - 1, argv + 1);
    else if (strcmp(argv[1], "timer") == 0)
        cmd_timer(argc - 1, argv + 1);
    else if (strcmp(argv[1], "pomodoro") == 0)
        cmd_pomodoro(argc - 1, argv + 1);
    else if (strcmp(argv[1], "status") == 0)
        cmd_status();
    else if (strcmp(argv[1], "stop") == 0)
        cmd_stop();
    else
        print_usage();

    return 0;
}
