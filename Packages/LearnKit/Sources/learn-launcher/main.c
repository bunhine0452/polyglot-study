/*
 * learn-launcher — 사용자 코드를 rlimit 과 독립 프로세스 그룹 안에 가두는 exec 래퍼.
 *
 * 왜 별도 헬퍼인가
 *   `posix_spawn` 에는 rlimit 옵션이 없고, `Subprocess` 의 `preSpawnProcessConfigurator`
 *   는 **부모(=앱) 프로세스에서** 돌기 때문에 거기서 `setrlimit` 을 부르면 앱 자신이
 *   묶인다. rlimit 은 `fork` 와 `execv` 사이에서만 자식에게 걸 수 있다.
 *
 * 규약
 *   learn-launcher --cpu N --nproc N --fsize N --wall N --status-fd 3 [--cwd D] -- <argv>
 *
 *     --cpu N        자식 프로세스당 CPU 초. soft=N, hard=N+1 — soft 초과 시 SIGXCPU,
 *                    무시하더라도 hard 에서 커널이 SIGKILL 한다. 0 = 무제한.
 *     --nproc N      **추가로 허용할** 프로세스 수. RLIMIT_NPROC 은 프로세스 트리가 아니라
 *                    실 uid 전체를 세므로 절대값 16 을 걸면 데스크톱에서는 fork 가 즉시
 *                    전부 실패한다(현재 사용자 프로세스가 이미 수백 개). 그래서 스폰 직전
 *                    실 uid 의 프로세스 수를 세어 `현재 + N` 으로 건다. 커널 회계와 몇 개
 *                    어긋나므로 보장은 "최소 N 개 허용". 0 = 무제한.
 *     --fsize N      파일 쓰기 상한 바이트. 초과 시 SIGXFSZ. 0 = 무제한.
 *     --wall N       벽시계 초. 초과 시 프로세스 그룹째 killpg(SIGKILL). 0 = 무제한.
 *     --status-fd N  런처가 사인을 흘릴 fd. 자식에게는 FD_CLOEXEC 로 가려 위조를 막는다.
 *     --cwd D        자식의 작업 디렉터리.
 *     --             이후 전부 자식 argv. argv[0] 은 execv 에 그대로 넘기므로 절대경로여야 한다.
 *
 * status fd 로 흘리는 줄 (각 줄 개행 종결, 순서 보장)
 *     SPAWNED <pid> <pgid>     execv 성공 직후 정확히 한 번
 *     TIMEOUT                  --wall 초과로 런처가 그룹을 죽였을 때만
 *     EXIT <code>              자식이 정상 종료
 *     SIGNAL <signo>           자식이 시그널로 종료
 *     ERR <stage> <errno>      런처 자신의 실패 — 이때만 종료코드 125
 *
 *   TIMEOUT 이 있어야 "벽시계 초과"와 "사용자 코드가 스스로 SIGKILL 을 맞음"을 구별할 수
 *   있다. 둘 다 최종적으로는 SIGNAL 9 로 보이기 때문이다.
 *
 * 종료 상태
 *   자식이 정상 종료하면 그 코드를 그대로 _exit 하고, 시그널로 죽었으면
 *   `signal(N, SIG_DFL); raise(N)` 으로 **런처 자신이 같은 시그널로 죽어** 재현한다.
 *   즉 런처는 종료 상태에 대해 투명하다. 125 는 런처 자신의 실패에만 쓴다.
 *
 * 메모리 상한은 여기 없다 — macOS 는 RLIMIT_AS / RLIMIT_DATA 를 지원하지 않는다(EINVAL).
 * 부모(Swift)가 SPAWNED 로 받은 pgid 를 proc_listpids 로 폴링해 killpg 한다.
 */

#include <errno.h>
#include <fcntl.h>
#include <libproc.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/event.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define LAUNCHER_FAILURE_EXIT 125
#define CHILD_PREEXEC_EXIT 127

enum launcher_stage {
    STAGE_ARGS = 1,
    STAGE_STATUS_FD,
    STAGE_PIPE,
    STAGE_FORK,
    STAGE_SETSID,
    STAGE_CHDIR,
    STAGE_RLIMIT_CPU,
    STAGE_RLIMIT_NPROC,
    STAGE_RLIMIT_FSIZE,
    STAGE_EXEC,
    STAGE_WAIT
};

static const char *stage_name(int stage) {
    switch (stage) {
    case STAGE_ARGS: return "args";
    case STAGE_STATUS_FD: return "status-fd";
    case STAGE_PIPE: return "pipe";
    case STAGE_FORK: return "fork";
    case STAGE_SETSID: return "setsid";
    case STAGE_CHDIR: return "chdir";
    case STAGE_RLIMIT_CPU: return "rlimit-cpu";
    case STAGE_RLIMIT_NPROC: return "rlimit-nproc";
    case STAGE_RLIMIT_FSIZE: return "rlimit-fsize";
    case STAGE_EXEC: return "exec";
    case STAGE_WAIT: return "wait";
    default: return "unknown";
    }
}

/* ---------- async-signal-safe 출력 ---------- */

static void write_all(int fd, const char *buf, size_t len) {
    while (len > 0) {
        ssize_t n = write(fd, buf, len);
        if (n < 0) {
            if (errno == EINTR) continue;
            return; /* fd 3 가 닫혔거나 없다 — 실행 자체를 실패시키지는 않는다 */
        }
        if (n == 0) return;
        buf += (size_t)n;
        len -= (size_t)n;
    }
}

static size_t put_str(char *dst, size_t cap, size_t off, const char *s) {
    while (*s != '\0' && off + 1 < cap) dst[off++] = *s++;
    return off;
}

static size_t put_long(char *dst, size_t cap, size_t off, long v) {
    char tmp[24];
    size_t n = 0;
    unsigned long u;
    if (v < 0) {
        if (off + 1 < cap) dst[off++] = '-';
        u = (unsigned long)(-(v + 1)) + 1UL;
    } else {
        u = (unsigned long)v;
    }
    do {
        tmp[n++] = (char)('0' + (int)(u % 10UL));
        u /= 10UL;
    } while (u > 0UL && n < sizeof tmp);
    while (n > 0 && off + 1 < cap) dst[off++] = tmp[--n];
    return off;
}

static int g_status_fd = -1;

static void status_write(const char *tag, const long *values, int count) {
    if (g_status_fd < 0) return;
    char line[128];
    size_t off = put_str(line, sizeof line, 0, tag);
    for (int i = 0; i < count; i++) {
        off = put_str(line, sizeof line, off, " ");
        off = put_long(line, sizeof line, off, values[i]);
    }
    off = put_str(line, sizeof line, off, "\n");
    write_all(g_status_fd, line, off);
}

static void status_err(int stage, int err) {
    if (g_status_fd < 0) return;
    char line[128];
    size_t off = put_str(line, sizeof line, 0, "ERR ");
    off = put_str(line, sizeof line, off, stage_name(stage));
    off = put_str(line, sizeof line, off, " ");
    off = put_long(line, sizeof line, off, err);
    off = put_str(line, sizeof line, off, "\n");
    write_all(g_status_fd, line, off);
}

/* 런처 자신의 실패. 사인은 fd 3 으로, 사람용 한 줄은 stderr 로. */
static void fail(int stage, int err, const char *detail) {
    status_err(stage, err);
    char line[512];
    size_t off = put_str(line, sizeof line, 0, "learn-launcher: ");
    off = put_str(line, sizeof line, off, stage_name(stage));
    if (detail != NULL) {
        off = put_str(line, sizeof line, off, " (");
        off = put_str(line, sizeof line, off, detail);
        off = put_str(line, sizeof line, off, ")");
    }
    off = put_str(line, sizeof line, off, ": ");
    off = put_str(line, sizeof line, off, strerror(err));
    off = put_str(line, sizeof line, off, "\n");
    write_all(STDERR_FILENO, line, off);
    _exit(LAUNCHER_FAILURE_EXIT);
}

static void usage(void) {
    static const char *text =
        "usage: learn-launcher [--cpu S] [--nproc N] [--fsize BYTES] [--wall S]\n"
        "                      [--status-fd FD] [--cwd DIR] -- PROGRAM [ARGS...]\n"
        "  PROGRAM 은 execv 로 그대로 넘어가므로 절대경로여야 한다. 0 은 '무제한'.\n"
        "  --nproc 는 절대값이 아니라 '현재 uid 프로세스 수 + N'.\n";
    write_all(STDERR_FILENO, text, strlen(text));
}

/* ---------- 부모 시그널 전달 ---------- */

static volatile sig_atomic_t g_forward_signal = 0;

static void on_terminating_signal(int sig) { g_forward_signal = sig; }

static double monotonic_seconds(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0.0;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

/* ---------- rlimit ---------- */

/* 하드 상한을 넘겨 EPERM 을 맞지 않도록 현재 하드 리밋으로 클램프한다. */
static int set_limit(int resource, rlim_t soft, rlim_t hard) {
    struct rlimit current;
    if (getrlimit(resource, &current) == 0 && current.rlim_max != RLIM_INFINITY) {
        if (soft > current.rlim_max) soft = current.rlim_max;
        if (hard > current.rlim_max) hard = current.rlim_max;
    }
    struct rlimit limit;
    limit.rlim_cur = soft;
    limit.rlim_max = hard;
    return setrlimit(resource, &limit);
}

/* ---------- 자식 ---------- */

/* pre-exec 실패는 CLOEXEC 파이프로 부모에 넘긴다. exec 이 성공하면 파이프가 닫혀
 * 부모는 EOF 를 본다 — 즉 부모는 "exec 성공"과 "exec 실패"를 확실히 구별한다. */
static void child_fail(int errfd, int stage, int err) {
    int message[2];
    message[0] = stage;
    message[1] = err;
    ssize_t ignored = write(errfd, message, sizeof message);
    (void)ignored;
    _exit(CHILD_PREEXEC_EXIT);
}

/* ---------- 종료 재현 ---------- */

static void reproduce_signal(int sig) {
    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_handler = SIG_DFL;
    sigemptyset(&action.sa_mask);
    sigaction(sig, &action, NULL);

    sigset_t set;
    sigemptyset(&set);
    sigaddset(&set, sig);
    sigprocmask(SIG_UNBLOCK, &set, NULL);

    raise(sig);
    /* 여기 도달했다면 시그널이 프로세스를 죽이지 않았다는 뜻 — 관례 코드로 떨어진다. */
    _exit(128 + sig);
}

/* 실 uid 가 지금 몇 개의 프로세스를 갖고 있는지. 커널이 RLIMIT_NPROC 을 실 uid 로
 * 회계하므로(chgproccnt) PROC_RUID_ONLY 로 센다.
 *
 * 함정: `proc_listpids(..., NULL, 0)` 은 **필터를 무시하고 시스템 전체 개수**를 돌려준다
 * (실측 2026-09-06: uid 프로세스 457 개인데 NULL 질의는 779 를 보고). 그래서 실제 버퍼를
 * 받아 세지 않으면 nproc 헤드룸이 300 이상 부풀어 fork bomb 을 놓친다.
 *
 * 실측 오차: 커널 회계와 이 집계가 8 개쯤 어긋나 `--nproc N` 은 실제로 N+8 근처에서
 * 막힌다. fork bomb 방어에는 무해하므로 "최소 N 개는 허용"으로 규정한다. */
static long count_user_processes(void) {
    uid_t uid = getuid();
    int upper_bound = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (upper_bound <= 0) upper_bound = 4096 * (int)sizeof(pid_t);
    size_t capacity = (size_t)upper_bound * 2;
    pid_t *pids = (pid_t *)malloc(capacity);
    if (pids == NULL) return 0;

    int bytes = proc_listpids(PROC_RUID_ONLY, (uint32_t)uid, pids, (int)capacity);
    long count = 0;
    if (bytes > 0) {
        size_t entries = (size_t)bytes / sizeof(pid_t);
        for (size_t i = 0; i < entries; i++) {
            if (pids[i] != 0) count++;
        }
    }
    free(pids);
    return count;
}

static int parse_nonnegative(const char *text, long *out) {
    if (text == NULL || *text == '\0') return -1;
    errno = 0;
    char *end = NULL;
    long value = strtol(text, &end, 10);
    if (errno != 0 || end == NULL || *end != '\0' || value < 0) return -1;
    *out = value;
    return 0;
}

int main(int argc, char **argv) {
    long cpu_seconds = 0;
    long extra_processes = 0;
    long file_size_bytes = 0;
    long wall_seconds = 0;
    long status_fd = -1;
    const char *working_directory = NULL;

    /* status fd 를 먼저 훑어 둔다 — 인자 오류조차 fd 3 으로 보고할 수 있어야 한다. */
    for (int i = 1; i + 1 < argc; i++) {
        if (strcmp(argv[i], "--") == 0) break;
        if (strcmp(argv[i], "--status-fd") == 0) {
            long value = -1;
            if (parse_nonnegative(argv[i + 1], &value) == 0) status_fd = value;
            break;
        }
    }
    if (status_fd >= 0) {
        int flags = fcntl((int)status_fd, F_GETFD);
        if (flags < 0) fail(STAGE_STATUS_FD, errno, "not open");
        g_status_fd = (int)status_fd;
        /* 자식이 status 라인을 위조하지 못하도록 exec 에서 닫는다. */
        (void)fcntl(g_status_fd, F_SETFD, flags | FD_CLOEXEC);
    }

    int index = 1;
    int saw_separator = 0;
    for (; index < argc; index++) {
        const char *option = argv[index];
        if (strcmp(option, "--") == 0) {
            index++;
            saw_separator = 1;
            break;
        }
        if (strcmp(option, "-h") == 0 || strcmp(option, "--help") == 0) {
            usage();
            return 0;
        }

        long *target = NULL;
        if (strcmp(option, "--cpu") == 0) target = &cpu_seconds;
        else if (strcmp(option, "--nproc") == 0) target = &extra_processes;
        else if (strcmp(option, "--fsize") == 0) target = &file_size_bytes;
        else if (strcmp(option, "--wall") == 0) target = &wall_seconds;
        else if (strcmp(option, "--status-fd") == 0) target = &status_fd;

        if (target != NULL) {
            if (index + 1 >= argc) fail(STAGE_ARGS, EINVAL, option);
            if (parse_nonnegative(argv[index + 1], target) != 0) fail(STAGE_ARGS, EINVAL, option);
            index++;
            continue;
        }
        if (strcmp(option, "--cwd") == 0) {
            if (index + 1 >= argc) fail(STAGE_ARGS, EINVAL, option);
            working_directory = argv[index + 1];
            index++;
            continue;
        }
        usage();
        fail(STAGE_ARGS, EINVAL, option);
    }

    if (!saw_separator || index >= argc) {
        usage();
        fail(STAGE_ARGS, EINVAL, "missing -- PROGRAM");
    }
    char *const *child_argv = &argv[index];
    if (child_argv[0][0] == '\0') fail(STAGE_ARGS, EINVAL, "empty program path");

    /* RLIMIT_NPROC 은 실 uid 전체를 센다 — 절대값이 아니라 현재값 기준 헤드룸으로 건다. */
    rlim_t nproc_limit = 0;
    if (extra_processes > 0) {
        nproc_limit = (rlim_t)(count_user_processes() + extra_processes);
    }

    int error_pipe[2];
    if (pipe(error_pipe) != 0) fail(STAGE_PIPE, errno, NULL);
    if (fcntl(error_pipe[1], F_SETFD, FD_CLOEXEC) != 0) fail(STAGE_PIPE, errno, NULL);

    /* 부모가 죽을 때 자식 그룹을 데려가도록, fork 전에 핸들러를 건다.
     * SA_RESTART 를 주지 않아 대기 중인 kevent 가 EINTR 로 깨어난다. */
    struct sigaction forward;
    memset(&forward, 0, sizeof forward);
    forward.sa_handler = on_terminating_signal;
    sigemptyset(&forward.sa_mask);
    forward.sa_flags = 0;
    sigaction(SIGTERM, &forward, NULL);
    sigaction(SIGINT, &forward, NULL);
    sigaction(SIGHUP, &forward, NULL);
    sigaction(SIGQUIT, &forward, NULL);
    signal(SIGPIPE, SIG_IGN); /* fd 3 이나 stdout 이 닫혀도 런처가 먼저 죽지 않게 */

    pid_t child = fork();
    if (child < 0) fail(STAGE_FORK, errno, NULL);

    if (child == 0) {
        close(error_pipe[0]);

        /* 상속된 시그널 상태를 지운다. 부모가 SIG_IGN 으로 둔 처리는 exec 을 넘어
         * 살아남으므로(특히 SIGPIPE), 여기서 되돌리지 않으면 사용자 코드가
         * 파이프가 끊긴 뒤에도 계속 돈다. */
        sigset_t empty;
        sigemptyset(&empty);
        sigprocmask(SIG_SETMASK, &empty, NULL);
        for (int sig = 1; sig < NSIG; sig++) {
            if (sig == SIGKILL || sig == SIGSTOP) continue;
            signal(sig, SIG_DFL);
        }

        /* 새 세션 + 새 프로세스 그룹. 이게 격리의 핵심이다 —
         *   1) 부모가 killpg 로 손자까지 한 번에 지울 수 있고,
         *   2) 사용자 코드가 kill(0, SIGKILL) 로 앱의 프로세스 그룹을 때릴 수 없다. */
        if (setsid() < 0) child_fail(error_pipe[1], STAGE_SETSID, errno);

        if (working_directory != NULL && chdir(working_directory) != 0) {
            child_fail(error_pipe[1], STAGE_CHDIR, errno);
        }

        if (cpu_seconds > 0) {
            /* soft 초과 시 SIGXCPU, 그걸 무시해도 hard 에서 커널이 SIGKILL 한다. */
            if (set_limit(RLIMIT_CPU, (rlim_t)cpu_seconds, (rlim_t)cpu_seconds + 1) != 0) {
                child_fail(error_pipe[1], STAGE_RLIMIT_CPU, errno);
            }
        }
        if (nproc_limit > 0) {
            if (set_limit(RLIMIT_NPROC, nproc_limit, nproc_limit) != 0) {
                child_fail(error_pipe[1], STAGE_RLIMIT_NPROC, errno);
            }
        }
        if (file_size_bytes > 0) {
            if (set_limit(RLIMIT_FSIZE, (rlim_t)file_size_bytes, (rlim_t)file_size_bytes) != 0) {
                child_fail(error_pipe[1], STAGE_RLIMIT_FSIZE, errno);
            }
        }
        /* 코어 덤프는 항상 끈다 — SIGXCPU·SIGSEGV 마다 수백 MB 를 쓰고
         * 크래시 리포터를 띄우면 학습 앱으로서는 그 자체가 사고다. */
        (void)set_limit(RLIMIT_CORE, 0, 0);

        execv(child_argv[0], child_argv);
        child_fail(error_pipe[1], STAGE_EXEC, errno);
    }

    /* ---------- 부모 ---------- */

    close(error_pipe[1]);

    int preexec[2] = {0, 0};
    size_t received = 0;
    while (received < sizeof preexec) {
        ssize_t n = read(error_pipe[0], (char *)preexec + received, sizeof preexec - received);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break; /* EOF = exec 성공 */
        received += (size_t)n;
    }
    close(error_pipe[0]);

    if (received == sizeof preexec) {
        int reaped_status = 0;
        while (waitpid(child, &reaped_status, 0) < 0 && errno == EINTR) { }
        fail(preexec[0], preexec[1], child_argv[0]);
    }

    /* setsid 성공이 확인됐으므로 pgid == pid 가 보장된다. */
    pid_t group = child;
    long spawned[2] = { (long)child, (long)group };
    status_write("SPAWNED", spawned, 2);

    int queue = kqueue();
    int use_queue = 0;
    if (queue >= 0) {
        struct kevent change;
        EV_SET(&change, (uintptr_t)child, EVFILT_PROC, EV_ADD | EV_ONESHOT, NOTE_EXIT, 0, NULL);
        if (kevent(queue, &change, 1, NULL, 0, NULL) == 0) use_queue = 1;
        /* ESRCH 면 이미 종료한 것 — 아래 waitpid 가 즉시 거둔다. */
    }

    double deadline = wall_seconds > 0 ? monotonic_seconds() + (double)wall_seconds : 0.0;
    int timed_out = 0;
    int status = 0;
    int killed_by_forward = 0;

    for (;;) {
        pid_t reaped = waitpid(child, &status, WNOHANG);
        if (reaped == child) break;
        if (reaped < 0) {
            if (errno == EINTR) continue;
            status = 0;
            break; /* ECHILD — 있을 수 없지만 무한 루프는 피한다 */
        }

        if (g_forward_signal != 0 && !killed_by_forward) {
            killpg(group, SIGKILL);
            killed_by_forward = 1;
        }

        double remaining = -1.0;
        if (wall_seconds > 0) {
            remaining = deadline - monotonic_seconds();
            if (remaining <= 0.0) {
                timed_out = 1;
                break;
            }
        }

        if (use_queue) {
            struct timespec wait_for;
            if (remaining >= 0.0) {
                wait_for.tv_sec = (time_t)remaining;
                wait_for.tv_nsec = (long)((remaining - (double)wait_for.tv_sec) * 1e9);
            } else {
                /* 무제한이어도 전달 시그널을 확인하러 1 초마다 깨운다. */
                wait_for.tv_sec = 1;
                wait_for.tv_nsec = 0;
            }
            struct kevent event;
            int n = kevent(queue, NULL, 0, &event, 1, &wait_for);
            if (n < 0 && errno != EINTR) use_queue = 0;
        } else {
            struct timespec nap = {0, 5L * 1000L * 1000L};
            nanosleep(&nap, NULL);
        }
    }

    if (timed_out) {
        status_write("TIMEOUT", NULL, 0);
        killpg(group, SIGKILL);
        kill(child, SIGKILL);
        for (;;) {
            pid_t reaped = waitpid(child, &status, 0);
            if (reaped == child) break;
            if (reaped < 0 && errno == EINTR) continue;
            break;
        }
    }

    /* 직계 자식이 끝나도 손자가 그룹에 남아 있을 수 있다. 항상 그룹째 정리한다.
     * (자기 그룹을 때리는 사고를 막기 위해 한 번 더 확인) */
    if (group > 0 && group != getpgrp()) killpg(group, SIGKILL);

    if (queue >= 0) close(queue);

    if (WIFEXITED(status)) {
        long code = WEXITSTATUS(status);
        status_write("EXIT", &code, 1);
        _exit((int)code);
    }
    if (WIFSIGNALED(status)) {
        int signal_number = WTERMSIG(status);
        long reported = signal_number;
        status_write("SIGNAL", &reported, 1);
        reproduce_signal(signal_number);
    }

    status_err(STAGE_WAIT, EINVAL);
    return LAUNCHER_FAILURE_EXIT;
}
