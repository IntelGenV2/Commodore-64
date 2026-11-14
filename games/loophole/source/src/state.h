#ifndef LOOPHOLE_STATE_H
#define LOOPHOLE_STATE_H

/* One five-second reveal at 50 game ticks per second. Zero means spent. */
enum { HINT_DURATION = 250, HINT_READY = 255 };

/* cc65 uses 16-bit little-endian ints and byte alignment. Version 1 stored
   a hint toggle in the same byte as the version 2 timer. */
struct RunState {
    unsigned player_x;
    int height8;
    unsigned char pass, feet, grounded, facing_left, gate, on_plate, progress;
    signed char velocity;
    unsigned char countdown, stride, coyote, jump_buffer, hint_ticks, lamp_count;
    unsigned char phase_ticks, charge, air_jump, launch_dir, parts, armed;
};

enum { DISK_OK, DISK_EMPTY, DISK_ERROR, DISK_NEW_RULE };
unsigned char save_run(const struct RunState *run);
unsigned char load_run(struct RunState *run);
#endif
