// libinput implementation for Jigglemil get_idle_time()
// Tracks mouse + keyboard activity via libinput and returns idle time in ms

#ifndef IDLE_DETECTOR_H
#define IDLE_DETECTOR_H

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <pthread.h>
#include <errno.h>
#include <string.h>
#include <poll.h>
#include <libinput.h>
#include <libudev.h>

static pthread_mutex_t idle_mutex = PTHREAD_MUTEX_INITIALIZER;
static struct timespec last_activity;

// ----------------------------
// Helper: open / close restricted for libinput
// ----------------------------
static int open_restricted(const char *path, int flags, void *userdata) {
    (void)userdata;
    return open(path, flags);
}

static void close_restricted(int fd, void *userdata) {
    (void)userdata;
    close(fd);
}

// ----------------------------
// Update idle timer
// ----------------------------
static void update_last_activity(void) {
    pthread_mutex_lock(&idle_mutex);
    clock_gettime(CLOCK_MONOTONIC, &last_activity);
    pthread_mutex_unlock(&idle_mutex);
}

// ----------------------------
// Input monitoring thread
// ----------------------------
static void* input_monitor_thread(void *arg) {
    (void)arg;

    struct libinput_interface iface = {
        .open_restricted  = open_restricted,
        .close_restricted = close_restricted
    };

    struct udev *udev_ctx = udev_new();
    if (!udev_ctx) {
        fprintf(stderr, "idle_detector: udev_new failed\n");
        return NULL;
    }

    struct libinput *li =
        libinput_udev_create_context(&iface, NULL, udev_ctx);
    if (!li) {
        fprintf(stderr,
                "idle_detector: libinput_udev_create_context failed\n");
        udev_unref(udev_ctx);
        return NULL;
    }

    if (libinput_udev_assign_seat(li, "seat0") != 0) {
        fprintf(stderr,
                "idle_detector: libinput_udev_assign_seat failed\n");
        libinput_unref(li);
        udev_unref(udev_ctx);
        return NULL;
    }

    int fd = libinput_get_fd(li);
    struct pollfd fds = {
        .fd     = fd,
        .events = POLLIN
    };

    while (1) {
        if (poll(&fds, 1, -1) < 0) {
            if (errno == EINTR)
                continue;

            perror("idle_detector: poll");
            break;
        }

        libinput_dispatch(li);

        struct libinput_event *ev;
        while ((ev = libinput_get_event(li)) != NULL) {
            enum libinput_event_type type =
                libinput_event_get_type(ev);

            switch (type) {
                case LIBINPUT_EVENT_KEYBOARD_KEY:
                case LIBINPUT_EVENT_POINTER_MOTION:
                case LIBINPUT_EVENT_POINTER_MOTION_ABSOLUTE:
                case LIBINPUT_EVENT_POINTER_BUTTON:
                case LIBINPUT_EVENT_POINTER_AXIS:
                    update_last_activity();
                    break;
                default:
                    break;
            }

            libinput_event_destroy(ev);
        }
    }

    libinput_unref(li);
    udev_unref(udev_ctx);
    return NULL;
}

// ----------------------------
// Public: initialize idle detector
// ----------------------------
static void init_idle_detector(void) {
    pthread_mutex_lock(&idle_mutex);
    clock_gettime(CLOCK_MONOTONIC, &last_activity);
    pthread_mutex_unlock(&idle_mutex);

    pthread_t tid;
    pthread_create(&tid, NULL, input_monitor_thread, NULL);
    pthread_detach(tid);
}

// ----------------------------
// Public: get idle time in milliseconds
// ----------------------------
static long get_idle_time(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);

    pthread_mutex_lock(&idle_mutex);
    long idle_ms =
        (now.tv_sec  - last_activity.tv_sec)  * 1000 +
        (now.tv_nsec - last_activity.tv_nsec) / 1000000;
    pthread_mutex_unlock(&idle_mutex);

    return idle_ms;
}

#endif // IDLE_DETECTOR_H
