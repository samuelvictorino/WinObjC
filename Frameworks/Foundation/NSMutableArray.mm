//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include "Starboard.h"

#include "CoreFoundation/CFArray.h"
#include "CoreFoundation/CFType.h"
#include "Foundation/NSMutableArray.h"
#include "../objcrt/runtime.h"

__declspec(dllimport) extern "C" int CFNSBlockCompare(id obj1, id obj2, void* block);
__declspec(dllimport) extern "C" int CFNSDescriptorCompare(id obj1, id obj2, void* block);

@implementation NSMutableArray : NSArray
+ (NSMutableArray*)arrayWithCapacity:(NSUInteger)numElements {
    NSMutableArray* newArray = [self new];

    return [newArray autorelease];
}

- (NSMutableArray*)initWithCapacity:(NSUInteger)numElements {
    [self init];

    return self;
}

- (void)removeAllObjects {
    CFArrayRemoveAllValues((CFMutableArrayRef)self);
}

- (void)addObject:(NSObject*)objAddr {
    CFArrayAppendValue((CFMutableArrayRef)self, (const void*)objAddr);
}

- (void)addObjectsFromArray:(NSArray*)fromArray {
    NSEnumerator* enumerator = [fromArray objectEnumerator];

    for (NSObject* curVal in enumerator) {
        CFArrayAppendValue((CFMutableArrayRef)self, (const void*)curVal);
    }
}

- (void)setArray:(NSArray*)fromArray {
    [self removeAllObjects];
    [self addObjectsFromArray:fromArray];
}

- (void)removeObjectsInArray:(NSArray*)fromArray {
    NSEnumerator* enumerator = [fromArray objectEnumerator];
    NSObject* curVal = [enumerator nextObject];

    while (curVal != nil) {
        [self removeObject:curVal];
        curVal = [enumerator nextObject];
    }
}

- (void)insertObject:(NSObject*)objAddr atIndex:(NSUInteger)index {
    CFArrayInsertValueAtIndex((CFMutableArrayRef)self, index, (const void*)objAddr);
}

- (void)insertObjects:(NSArray*)objects atIndexes:(NSIndexSet*)indexes {
    NSInteger i;
    NSInteger index = [indexes firstIndex];
    int count = [objects count];
    for (i = 0; i < count; i++) {
        [self insertObject:[objects objectAtIndex:i] atIndex:index];
        index = [indexes indexGreaterThanIndex:index];
    }
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(NSObject*)obj {
    if (object_getClass(self) == [NSMutableArrayConcrete class]) {
        //  Fastpath
        CFRange range;
        range.location = index;
        range.length = 1;
        CFArrayReplaceValues((CFMutableArrayRef)self, range, (const void**)&obj, 1);
    } else {
        [obj retain];
        [self removeObjectAtIndex:index];
        [self insertObject:obj atIndex:index];
        [obj release];
    }
}

- (void)setObject:(NSObject*)obj atIndexedSubscript:(NSUInteger)index {
    if (index == [self count]) {
        [self addObject:obj];
    } else {
        [self replaceObjectAtIndex:index withObject:obj];
    }
}

- (void)exchangeObjectAtIndex:(NSUInteger)atIndex withObjectAtIndex:(NSUInteger)withIndex {
    NSObject* obj1 = [self objectAtIndex:atIndex];
    NSObject* obj2 = [self objectAtIndex:withIndex];

    [obj1 retain];
    [obj2 retain];

    [self replaceObjectAtIndex:atIndex withObject:obj2];
    [self replaceObjectAtIndex:withIndex withObject:obj1];

    [obj1 release];
    [obj2 release];
}

- (void)removeObject:(NSObject*)objAddr {
    if (objAddr == nil) {
        EbrDebugLog("objAddr = nil!\n");
    }

    int idx = [self indexOfObject:objAddr];
    if (idx != NSNotFound) {
        [self removeObjectAtIndex:idx];
    }
}

- (void)removeObject:(NSObject*)objAddr inRange:(NSRange)range {
    for (int i = range.location + range.length - 1; i >= (int)range.location; i--) {
        id curObj = [self objectAtIndex:i];

        if ([curObj isEqual:objAddr]) {
            [self removeObject:curObj];
        }
    }
}

- (void)removeObjectsInRange:(NSRange)range {
    for (int i = range.location + range.length - 1; i >= (int)range.location; i--) {
        [self removeObjectAtIndex:i];
    }
}

- (void)removeObjectIdenticalTo:(NSObject*)objAddr {
    int idx = [self indexOfObjectIdenticalTo:objAddr];
    if (idx != NSNotFound) {
        [self removeObjectAtIndex:idx];
    }
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    CFArrayRemoveValueAtIndex((CFMutableArrayRef)self, index);
}

- (void)removeObjectsAtIndexes:(NSIndexSet*)index {
    [index _removeFromArray:self];
}

- (void)_moveObjectAtIndexToEnd:(NSUInteger)index {
    CFArrayMoveValueAtIndexToEnd((CFMutableArrayRef)self, index);
}

- (void)removeLastObject {
    NSUInteger count = [self count];

    CFArrayRemoveValueAtIndex((CFMutableArrayRef)self, count - 1);
}

static void swap(NSMutableArray* self, uint32_t a, uint32_t b) {
    if (a == b)
        return;

    id obj1 = [self objectAtIndex:a];
    id obj2 = [self objectAtIndex:b];

    [obj1 retain];
    [obj2 retain];
    [self replaceObjectAtIndex:b withObject:obj1];
    [self replaceObjectAtIndex:a withObject:obj2];
    [obj1 release];
    [obj2 release];
}

static void shortsort(NSMutableArray* self, uint32_t lo, uint32_t hi, uint32_t compFunc, uint32_t context) {
    int p, max;

    while (hi > lo) {
        max = lo;
        for (p = lo + 1; p <= (int)hi; p += 1) {
            if (((signed int)EbrCall(compFunc, "ddd", [self objectAtIndex:p], [self objectAtIndex:max], context)) > 0)
                max = p;
        }

        swap(self, max, hi);
        hi -= 1;
    }
}

static signed int selComp(NSMutableArray* self, int i1, int i2, SEL selector) {
    typedef int (*ftype)(id self, SEL sel, ...);
    ftype f = (ftype)class_getMethodImplementation(object_getClass([self objectAtIndex:i1]), selector);
    return f([self objectAtIndex:i1], selector, [self objectAtIndex:i2]);
}

static void shortsort(NSMutableArray* self, uint32_t lo, uint32_t hi, SEL selector) {
    DWORD p, max;

    while (hi > lo) {
        max = lo;
        for (p = lo + 1; p <= hi; p += 1) {
            if (selComp(self, p, max, selector) > 0)
                max = p;
        }

        swap(self, max, hi);
        hi -= 1;
    }
}

- (void)sortUsingComparator:(NSComparator*)comparator {
    [self sortUsingFunction:CFNSBlockCompare context:comparator];
}

#define CUTOFF 8

- (void)sortUsingFunction:(uint32_t)compFunc context:(uint32_t)context {
    NSUInteger count = [self count];

    [self sortUsingFunction:compFunc context:context range:NSMakeRange(0, count)];
}

- (void)sortUsingFunction:(uint32_t)compFunc context:(uint32_t)context range:(NSRange)range {
    uint32_t base = range.location;
    uint32_t num = range.length;

    uint32_t lo, hi;
    uint32_t mid;
    uint32_t loguy, higuy;
    uint32_t size;
    uint32_t lostk[30], histk[30];
    int stkptr;

    if (num < 2)
        return;
    stkptr = 0;

    lo = base;
    hi = base + (num - 1);

recurse:
    size = (hi - lo) + 1;

    if (size <= CUTOFF) {
        shortsort(self, lo, hi, compFunc, context);
    } else {
        mid = lo + (size / 2);
        swap(self, mid, lo);

        loguy = lo;
        higuy = hi + 1;

        for (;;) {
            do {
                loguy += 1;
            } while (loguy <= hi &&
                     ((signed int)EbrCall(
                         compFunc, "ddd", [self objectAtIndex:loguy], [self objectAtIndex:lo], context)) <= 0);

            do {
                higuy -= 1;
            } while (higuy > lo &&
                     ((signed int)EbrCall(
                         compFunc, "ddd", [self objectAtIndex:higuy], [self objectAtIndex:lo], context)) >= 0);

            if (higuy < loguy)
                break;
            swap(self, loguy, higuy);
        }

        swap(self, lo, higuy);

        if (higuy - 1 - lo >= hi - loguy) {
            if (lo + 1 < higuy) {
                lostk[stkptr] = lo;
                histk[stkptr] = higuy - 1;
                ++stkptr;
            }

            if (loguy < hi) {
                lo = loguy;
                goto recurse;
            }
        } else {
            if (loguy < hi) {
                lostk[stkptr] = loguy;
                histk[stkptr] = hi;
                ++stkptr;
            }

            if (lo + 1 < higuy) {
                hi = higuy - 1;
                goto recurse;
            }
        }
    }

    --stkptr;
    if (stkptr >= 0) {
        lo = lostk[stkptr];
        hi = histk[stkptr];
        goto recurse;
    }
}

- (void)sortUsingSelector:(SEL)selector {
    uint32_t base = 0;
    uint32_t num = [self count];

    uint32_t lo, hi;
    uint32_t mid;
    uint32_t loguy, higuy;
    unsigned size;
    uint32_t lostk[30], histk[30];
    int stkptr;

    if (num < 2)
        return;
    stkptr = 0;

    lo = base;
    hi = base + (num - 1);

recurse:
    size = (hi - lo) + 1;

    if (size <= CUTOFF) {
        shortsort(self, lo, hi, selector);
    } else {
        mid = lo + (size / 2);
        swap(self, mid, lo);

        loguy = lo;
        higuy = hi + 1;

        for (;;) {
            do {
                loguy += 1;
            } while (loguy <= hi && selComp(self, loguy, lo, selector) <= 0);

            do {
                higuy -= 1;
            } while (higuy > lo && selComp(self, higuy, lo, selector) >= 0);

            if (higuy < loguy)
                break;
            swap(self, loguy, higuy);
        }

        swap(self, lo, higuy);

        if (higuy - 1 - lo >= hi - loguy) {
            if (lo + 1 < higuy) {
                lostk[stkptr] = lo;
                histk[stkptr] = higuy - 1;
                ++stkptr;
            }

            if (loguy < hi) {
                lo = loguy;
                goto recurse;
            }
        } else {
            if (loguy < hi) {
                lostk[stkptr] = loguy;
                histk[stkptr] = hi;
                ++stkptr;
            }

            if (lo + 1 < higuy) {
                hi = higuy - 1;
                goto recurse;
            }
        }
    }

    --stkptr;
    if (stkptr >= 0) {
        lo = lostk[stkptr];
        hi = histk[stkptr];
        goto recurse;
    }
}

- (void)sortUsingDescriptors:(NSArray*)descriptors {
    [self sortUsingFunction:CFNSDescriptorCompare context:descriptors];
}

- (NSObject*)copyWithZone:(NSZone*)zone {
    NSArray* ret = [[NSArray alloc] initWithArray:self];

    return ret;
}

+ (NSObject*)allocWithZone:(NSZone*)zone {
    if (self == [NSMutableArray class])
        return NSAllocateObject((Class)[NSMutableArrayConcrete class], 0, zone);

    return NSAllocateObject((Class)self, 0, zone);
}

- (void)filterUsingPredicate:(NSPredicate*)predicate {
    if (predicate == nil) {
        //[NSException raise:NSInvalidArgumentException format:@"-[%@ %s] predicate is nil",isa,_cmd];
        assert(0);
        return;
    }

    NSInteger count = [self count];

    while (--count >= 0) {
        id check = [self objectAtIndex:count];

        if (![predicate evaluateWithObject:check])
            [self removeObjectAtIndex:count];
    }
}

@end

extern FILE* fpLogCallsOut;

@implementation NSMutableArrayConcrete : NSMutableArray
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(DWORD)maxCount {
    NSUInteger count = CFArrayGetCount((CFArrayRef)self);
    if (state->state >= count)
        return 0;

    state->itemsPtr = (id*)_CFArrayGetPtr((CFArrayRef)self);
    state->state = count;
    state->mutationsPtr = (unsigned long*)self;

    return count;
}

@end
