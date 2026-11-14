#import "GrappaHelper.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

static void ALSetError(char *err_buf, size_t err_len, const char *message) {
    if (err_buf && err_len > 0) {
        snprintf(err_buf, err_len, "%s", message ? message : "unknown Grappa error");
    }
}

__attribute__((visibility("default"), used))
int ALGetGrappaToken(
    uint32_t in_version,
    uint32_t in_device_type,
    uint32_t in_protocol_version,
    uint8_t *out_buf,
    size_t max_len,
    size_t *out_len,
    char *err_buf,
    size_t err_len
) {
    if (!out_buf || max_len == 0 || !out_len) {
        ALSetError(err_buf, err_len, "invalid Grappa output buffer");
        return -1;
    }
    *out_len = 0;

    @autoreleasepool {
        @try {
            // A client request must be produced by Apple's host-side Grappa
            // implementation. Do not silently substitute a captured token.
            void *framework = dlopen(
                "/System/Library/PrivateFrameworks/AirTrafficHost.framework/AirTrafficHost",
                RTLD_NOW
            );
            if (!framework) {
                framework = dlopen(
                    "/System/Library/PrivateFrameworks/AirTrafficDevice.framework/AirTrafficDevice",
                    RTLD_NOW
                );
            }
            if (!framework) {
                ALSetError(err_buf, err_len, dlerror());
                return -2;
            }

            Class sessionClass = objc_getClass("ATGrappaSession");
            if (!sessionClass) {
                ALSetError(err_buf, err_len, "ATGrappaSession class not found in AirTraffic");
                return -3;
            }

            NSDictionary *deviceInfo = nil;
            if (in_device_type != 0) {
                deviceInfo = @{
                    @"version": @(in_version != 0 ? in_version : 1),
                    @"deviceType": @(in_device_type),
                    @"protocolVersion": @(in_protocol_version != 0 ? in_protocol_version : 1)
                };
            } else {
                id (*getDeviceInfo)(void) = (id (*)(void))dlsym(framework, "ATGrappaDeviceInfo");
                if (getDeviceInfo) {
                    id candidateInfo = getDeviceInfo();
                    if ([candidateInfo isKindOfClass:[NSDictionary class]]) {
                        deviceInfo = candidateInfo;
                    }
                }
                if (!deviceInfo) {
                    deviceInfo = @{
                        @"version": @(in_version != 0 ? in_version : 1),
                        @"deviceType": @0,
                        @"protocolVersion": @(in_protocol_version != 0 ? in_protocol_version : 1)
                    };
                }
            }

            SEL initSelector = sel_registerName("initWithType:");
            SEL hostSelector = sel_registerName("establishHostSessionWithDeviceInfo:clientRequestData:");
            id session = [sessionClass alloc];

            if (![session respondsToSelector:initSelector]) {
                ALSetError(err_buf, err_len, "ATGrappaSession does not expose initWithType:");
                return -4;
            }

            session = ((id (*)(id, SEL, unsigned int))objc_msgSend)(session, initSelector, 1);
            if (!session) {
                ALSetError(err_buf, err_len, "ATGrappaSession host initialization failed");
                return -4;
            }

            if (![session respondsToSelector:hostSelector]) {
                ALSetError(
                    err_buf,
                    err_len,
                    "Host Grappa generation is unavailable: CoreFP host session is not exposed on this iOS build"
                );
                return -5;
            }

            NSData *clientRequestData = nil;
            NSError *sessionError = ((id (*)(id, SEL, id, id *))objc_msgSend)(
                session,
                hostSelector,
                deviceInfo,
                &clientRequestData
            );

            if (sessionError) {
                ALSetError(err_buf, err_len, [[sessionError localizedDescription] UTF8String]);
                return -6;
            }

            if (![clientRequestData isKindOfClass:[NSData class]] || [clientRequestData length] == 0) {
                ALSetError(
                    err_buf,
                    err_len,
                    "Apple host Grappa session returned no client request data; refusing an unauthenticated AirTraffic sync"
                );
                return -7;
            }

            size_t length = [clientRequestData length];
            if (length > max_len) {
                if (err_buf && err_len > 0) {
                    snprintf(err_buf, err_len, "Grappa token exceeds output buffer: %zu > %zu", length, max_len);
                }
                return -8;
            }

            memcpy(out_buf, [clientRequestData bytes], length);
            *out_len = length;
            return 0;
        } @catch (NSException *exception) {
            ALSetError(err_buf, err_len, [[exception description] UTF8String]);
            return -99;
        }
    }
}
