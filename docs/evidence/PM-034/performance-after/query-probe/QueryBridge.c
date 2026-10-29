#include "QueryBridge.h"
CFArrayRef TPCreateReference(CGWindowID window) {
    CFArrayRef list = CGWindowListCreate(kCGWindowListOptionAll, kCGNullWindowID);
    if (!list) return NULL;
    for (CFIndex i=0; i<CFArrayGetCount(list); i++) {
        const void *token = CFArrayGetValueAtIndex(list, i);
        CFArrayRef one = CFArrayCreate(kCFAllocatorDefault, &token, 1, NULL);
        CFArrayRef descriptions = CGWindowListCreateDescriptionFromArray(one);
        Boolean matches = false;
        if (descriptions && CFArrayGetCount(descriptions)==1) {
            CFDictionaryRef row = CFArrayGetValueAtIndex(descriptions,0);
            CFNumberRef number = CFDictionaryGetValue(row,kCGWindowNumber);
            int64_t value = -1;
            if (number && CFGetTypeID(number)==CFNumberGetTypeID() && CFNumberGetValue(number,kCFNumberSInt64Type,&value)) matches = value == window;
        }
        if (descriptions) CFRelease(descriptions);
        if (matches) { CFRelease(list); return one; }
        CFRelease(one);
    }
    CFRelease(list); return NULL;
}
CFArrayRef TPCreateOnscreenTrackedDescription(CFArrayRef reference, int *membership) {
    *membership = -1;
    if (!reference || CFArrayGetCount(reference) != 1) return NULL;
    CFArrayRef list = CGWindowListCreate(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (!list) return NULL;
    /* Preserve the API-returned token; never reinterpret it as CFNumber or dereference it. */
    const void *token = CFArrayGetValueAtIndex(reference, 0);
    Boolean found = CFArrayContainsValue(list, CFRangeMake(0, CFArrayGetCount(list)), token);
    CFRelease(list);
    *membership = found ? 1 : 0;
    return found ? CGWindowListCreateDescriptionFromArray(reference) : NULL;
}
