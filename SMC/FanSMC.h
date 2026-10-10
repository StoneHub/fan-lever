#include <stdint.h>
int fl_open(uint32_t *connection);
void fl_close(uint32_t connection);
int fl_read(uint32_t connection, const char *key, double *value);
int fl_write(uint32_t connection, const char *key, double value);
