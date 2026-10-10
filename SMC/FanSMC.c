// AppleSMC userspace wire format; see docs/architecture.md for provenance.
#include "FanSMC.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPowerSources.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } Version;
typedef struct { uint16_t version, length; uint32_t cpu, gpu, memory; } Limits;
typedef struct { uint32_t size, type; uint8_t attributes; } KeyInfo;
typedef struct {
    uint32_t key; Version version; Limits limits; KeyInfo info;
    uint8_t result, status, command; uint32_t index; uint8_t bytes[32];
} Packet;
_Static_assert(sizeof(Packet) == 80, "Unexpected SMC packet layout");
_Static_assert(offsetof(Packet, bytes) == 48, "Unexpected SMC bytes offset");
static uint32_t fourcc(const char *s) {
    return ((uint32_t)(uint8_t)s[0]<<24)|((uint32_t)(uint8_t)s[1]<<16)|((uint32_t)(uint8_t)s[2]<<8)|(uint8_t)s[3];
}
static int call(uint32_t connection, Packet *in, Packet *out) {
    size_t size = sizeof(*out);
    kern_return_t result = IOConnectCallStructMethod(connection, 2, in, sizeof(*in), out, &size);
    if (result != KERN_SUCCESS) return (int)result;
    if (size != sizeof(*out)) return -1;
    return out->result ? 0x10000 + out->result : 0;
}
static int info(uint32_t connection, const char *key, KeyInfo *value) {
    if (!key || strlen(key) != 4) return -2;
    Packet in = {0}, out = {0}; in.key = fourcc(key); in.command = 9;
    int error = call(connection, &in, &out);
    if (error) return error;
    if (out.info.size == 0 || out.info.size > 32) return -3;
    *value = out.info; return 0;
}
int fl_open(uint32_t *connection) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -4;
    int error = IOServiceOpen(service, mach_task_self_, 0, connection);
    IOObjectRelease(service); return error;
}
void fl_close(uint32_t connection) { if (connection) IOServiceClose(connection); }
int fl_on_battery(void) {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return 1; // Unknown power uses the shorter limit.
    CFStringRef source = IOPSGetProvidingPowerSourceType(info);
    int limited = !source || !CFEqual(source, CFSTR(kIOPMACPowerKey));
    CFRelease(info); return limited;
}
int fl_read(uint32_t connection, const char *key, double *value) {
    Packet in = {0}, out = {0}; int error = info(connection, key, &in.info);
    if (error) return error;
    in.key = fourcc(key); in.command = 5;
    error = call(connection, &in, &out); if (error) return error;
    if (in.info.type == fourcc("flt ") && in.info.size == 4) {
        float f; memcpy(&f, out.bytes, 4); *value = f;
    } else if (in.info.type == fourcc("ui8 ") && in.info.size == 1) *value = out.bytes[0];
    else if (in.info.type == fourcc("fpe2") && in.info.size == 2) *value = ((out.bytes[0]<<8)|out.bytes[1])/4.0;
    else return -5;
    return isfinite(*value) ? 0 : -6;
}
int fl_write(uint32_t connection, const char *key, double value) {
    // This primitive is linked only into the helper and host. XPC never exposes keys or raw values.
    if (!isfinite(value) || value < 0 || value > 20000) return -7;
    Packet in = {0}, out = {0}; int error = info(connection, key, &in.info);
    if (error) return error;
    if (in.info.type == fourcc("flt ") && in.info.size == 4) { float f = value; memcpy(in.bytes, &f, 4); }
    else if (in.info.type == fourcc("ui8 ") && in.info.size == 1 && value <= 255) in.bytes[0] = value;
    else if (in.info.type == fourcc("fpe2") && in.info.size == 2 && value <= 16383) {
        uint16_t encoded = (uint16_t)(value*4); in.bytes[0] = encoded>>8; in.bytes[1] = encoded & 255;
    } else return -5;
    in.key = fourcc(key); in.command = 6; return call(connection, &in, &out);
}
