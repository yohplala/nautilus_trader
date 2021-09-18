#ifndef add_h
#define add_h

/* Warning, this file is autogenerated by cbindgen. Don't modify this manually. */

#include <stdint.h>

typedef struct Price {
  int64_t value;
  uintptr_t prec;
} Price;

typedef struct Quantity {
  uint64_t value;
  uintptr_t prec;
} Quantity;

struct Price new_price(double value, uintptr_t prec);

struct Quantity new_qty(double value, uintptr_t prec);

#endif /* add_h */
