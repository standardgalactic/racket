#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#ifdef USE_THREAD_TEST
#include <pthread.h>
#endif

typedef unsigned char byte;

#ifdef _WIN32
#define X __declspec(dllexport)
#else
#define X
#endif

X void* return_null() { return NULL; }

X int  add1_int_int   (int  x) { return x + 1; }
X int  add1_byte_int  (byte x) { return x + 1; }
X byte add1_int_byte  (int  x) { return x + 1; }
X byte add1_byte_byte (byte x) { return x + 1; }
X float add1_float_float (float  x) { return x + 1; }
X double add1_double_double (double  x) { return x + 1; }
X int  decimal_int_int_int    (int  x, int  y) { return 10*x + y; }
X int  decimal_byte_int_int   (byte x, int  y) { return 10*x + y; }
X int  decimal_int_byte_int   (int  x, byte y) { return 10*x + y; }
X int  decimal_byte_byte_int  (byte x, byte y) { return 10*x + y; }
X byte decimal_int_int_byte   (int  x, int  y) { return 10*x + y; }
X byte decimal_byte_int_byte  (byte x, int  y) { return 10*x + y; }
X byte decimal_int_byte_byte  (int  x, byte y) { return 10*x + y; }
X byte decimal_byte_byte_byte (byte x, byte y) { return 10*x + y; }

X int   callback3_int_int_int     (int(*f)(int))   { if (f) return f(3); else return 79; }
X int   callback3_byte_int_int    (int(*f)(byte))  { return f(3); }
X int   callback3_short_int_int   (int(*f)(short)) { return f(3); }
X int   callback3_int_byte_int    (byte(*f)(int))  { return f(3); }
X int   callback3_int_short_int   (short(*f)(int)) { return f(3); }
X int   callback3_byte_byte_int   (byte(*f)(byte)) { return f(3); }
X int   callback3_short_short_int (short(*f)(short)) { return f(3); }
X byte  callback3_int_int_byte    (int(*f)(int))   { return f(3); }
X short callback3_int_int_short   (int(*f)(int))   { return f(3); }
X byte  callback3_byte_int_byte   (int(*f)(byte))  { return f(3); }
X short callback3_short_int_short (int(*f)(short))  { return f(3); }
X byte  callback3_int_byte_byte   (byte(*f)(int))  { return f(3); }
X short callback3_int_short_short (short(*f)(int))  { return f(3); }
X byte  callback3_byte_byte_byte  (byte(*f)(byte)) { return f(3); }
X short  callback3_short_short_short(short(*f)(short)) { return f(3); }
X float  callback3_float_float_float(float(*f)(float)) { return f(3.0); }
X double  callback3_double_double_double(double(*f)(double)) { return f(3.0); }

X int g1;
X int  curry_ret_int_int   (int  x) { return g1 + x; }
X int  curry_ret_byte_int  (byte x) { return g1 + x; }
X byte curry_ret_int_byte  (int  x) { return g1 + x; }
X byte curry_ret_byte_byte (byte x) { return g1 + x; }
X void* curry_int_int_int   (int  x)  { g1 = x; return &curry_ret_int_int;   }
X void* curry_byte_int_int  (byte x)  { g1 = x; return &curry_ret_int_int;   }
X void* curry_int_byte_int  (int  x)  { g1 = x; return &curry_ret_byte_int;  }
X void* curry_byte_byte_int (byte x)  { g1 = x; return &curry_ret_byte_int;  }
X void* curry_int_int_byte  (int  x)  { g1 = x; return &curry_ret_int_byte;  }
X void* curry_byte_int_byte (byte x)  { g1 = x; return &curry_ret_int_byte;  }
X void* curry_int_byte_byte (int  x)  { g1 = x; return &curry_ret_byte_byte; }
X void* curry_byte_byte_byte(byte x)  { g1 = x; return &curry_ret_byte_byte; }

X int g2;
X int ho_return(int x) { return g2 + x; }
X void* ho(int(*f)(int), int x) { g2 = f(x); return ho_return; }

X void *g3 = NULL;
X int use_g3(int x) { return ((int(*)(int))g3)(x); }

/* typedef int(*int2int)(int); */
/* typedef int2int(*int_to_int2int)(int); */
/* int hoho(int x, int_to_int2int f) { */
X int hoho(int x, int(*(*f)(int))(int)) { return (f(x+1))(x-1); }

X int grab7th(void *p) { return ((char *)p)[7]; }

X char *second_string(char **x) { return x[1]; }

X void reverse_strings(char **x) {
  while (*x) {
    int i, len;
    char *s;
    for (len = 0; (*x)[len] != 0; len++);
    s = malloc(len + 1);
    for (i = 0; i < len; i++)
      s[i] = (*x)[len - i - 1];
    s[len] = 0;
    *x = s;
    x++;
  }
}

X int vec4(int x[]) { return x[0]+x[1]+x[2]+x[3]; }

typedef struct _char_int { unsigned char a; int b; } char_int;
X int charint_to_int(char_int x) { return ((int)x.a) + x.b; }
X char_int int_to_charint(int x) {
  char_int result;
  result.a = (unsigned char)x;
  result.b = x;
  return result;
}
X char_int charint_swap(char_int x) {
  char_int result;
  result.a = (unsigned char)x.b;
  result.b = (int)x.a;
  return result;
}

int(*grabbed_callback)(int) = NULL;
X void grab_callback(int(*f)(int)) { grabbed_callback = f; }
X int use_grabbed_callback(int n) { return grabbed_callback(n); }

typedef char c7_array[7];

X char* increment_c_array(c7_array c) {
  int i;
  for (i = 0; i < 7; i++)
    c[i]++;
  return c;
}

struct char7 {
  char c[7];
};
struct int_char7_int {
  int i1;
  struct char7 c7;
  int i2;
};

X struct int_char7_int increment_ic7i(struct int_char7_int v)
{
  int i;

  v.i1++;
  for (i = 0; i < 7; i++)
    v.c7.c[i]++;
  v.i2++;

  return v;
}

X struct int_char7_int ic7i_cb(struct int_char7_int v,
                               struct int_char7_int (*cb)(struct int_char7_int))
{
  int i;

  --v.i1;
  for (i = 0; i < 7; i++)
    --v.c7.c[i];
  --v.i2;

  v = cb(v);

  v.i1++;
  for (i = 0; i < 7; i++)
    v.c7.c[i]++;
  v.i2++;

  return v;
}

X char* increment_2d_array(char c[3][7]) {
  int i, j;
  for (i = 0; i < 7; i++) {
    for (j = 0; j < 3; j++) {
      c[j][i] += (i + j);
    }
  }
  return (char *)c;
}

X int with_2d_array_cb(void (*cb)(char c[3][7]))
{
  char c[3][7];
  int i, j, r;

  for (i = 0; i < 3; i++) {
    for (j = 0; j < 7; j++) {
      c[i][j] = (i + (2 * j));
    }
  }
  
  cb(c);

  r = 0;
  for (i = 0; i < 3; i++) {
    for (j = 0; j < 7; j++) {
      r += (c[i][j] - ((2 * i) + (2 * j)));
    }
  }

  return r;
}

union borl {
  char b;
  long l;
};

X union borl increment_borl(int which, union borl v)
{
  int i;

  if (which) {
    v.l++;
  } else {
    v.b++;
  }

  return v;
}

union iord {
  int i;
  double d;
};

X union iord increment_iord(int which, union iord v)
{
  int i;

  if (which) {
    v.d++;
  } else {
    v.i++;
  }

  return v;
}

union dorf {
  double d;
  float f;
};

X union dorf increment_dorf(int which, union dorf v)
{
  int i;

  if (which) {
    v.f++;
  } else {
    v.d++;
  }

  return v;
}

union dor2f {
  double d;
  float f[2];
};

X union dor2f increment_dor2f(int which, union dor2f v)
{
  int i;

  if (which) {
    v.f[0]++;
    v.f[1]++;
  } else {
    v.d++;
  }

  return v;
}

union ic7iorl {
  struct int_char7_int ic7i;
  long l;
};

X union ic7iorl increment_ic7iorl(int which, union ic7iorl v)
{
  int i;

  if (which) {
    v.l++;
  } else {
    v.ic7i.i1++;
    for (i = 0; i < 7; i++)
      v.ic7i.c7.c[i]++;
    v.ic7i.i2++;
  }

  return v;
}

#ifdef USE_THREAD_TEST
typedef void* (*test_callback_t)(void*);
typedef void (*sleep_callback_t)();

void *do_f(void *_data)
{
  test_callback_t f = ((void **)_data)[0];
  void *data = ((void **)_data)[1];

  data = f(data);
  
  ((void **)_data)[2] = (void *)1;
  
  return data;
}

X void** foreign_thread_callback_setup(test_callback_t f,
                                      void *data)
{
  pthread_t th;
  void **d;

  d = malloc(4 * sizeof(void*));
  d[0] = f;
  d[1] = data;
  d[2] = NULL;

  if (pthread_create(&th, NULL, do_f, d))
    return NULL;

  d[3] = (void *)th;

  return d;
}

X int foreign_thread_callback_check_done(void **d)
{
  return d[2] != NULL;
}

X void *foreign_thread_callback_finish(void **d)
{
  void *r;
  pthread_t th = (pthread_t)d[3];

  if (pthread_join(th, &r))
    return NULL;

  free(d);

  return r;
}

/* only works if callbacks can be in non-atomic mode: */
X void* foreign_thread_callback(test_callback_t f,
                                void *data,
                                sleep_callback_t s)
{
  void **d = foreign_thread_callback_setup(f, data);

  while (!foreign_thread_callback_check_done(d)) {
    s();
  }

  return foreign_thread_callback_finish(d);
}
#endif

/* This testing function doesn't work reliably on Windows, because it sometimes
 * writes to a different errno. */
X int check_multiple_of_ten(int v) {
  int r = v % 10;
  if (r == 0) {
    return 0;
  } else {
    errno = r;
    return -1;
  }
}

X int sum_after_callback(int *a, int n, void (*cb)()) {
  int i, s = 0;

  cb();

  for (i = 0; i < n; i++)
    s += a[i];

  return s;
}

typedef int (*varargs_callback)(int, int, ...);

X long varargs_check(int init, int n, ...) {
  va_list va;
  long accum = init;
  
  va_start(va, n);

  while (n-- > 0) {
    int kind = va_arg(va, int);
    switch (kind) {
    case 1:
      accum += va_arg(va, int);
      break;
    case 2:
      accum += va_arg(va, long);
      break;
    case 3:
      accum += va_arg(va, double);
      break;
    case 4:
      accum += *(va_arg(va, int*));
      break;
    case 5:
      accum += (va_arg(va, varargs_callback))(1, 2, 3.0);
      break;
    default:
      accum = -1;
      n = 0;
      break;
    }
  }
  
  va_end(va);

  return accum;
}

X int callback_hungry(int (*f)(void*)) {
  char use_stack_space[10000];
  return f(use_stack_space);
}
