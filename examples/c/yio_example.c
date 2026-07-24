#include <yio.h>

/**
 * Custom type example
 */
typedef struct {
    int x;
    int y;
} Point;

/**
 * Custom printing callback for Point.
 * This function will be called by Yio when formatting a Point object.
 */
static int print_point(yio_printctx_t *t) {
    // The callback must call yio_printctx_va_arg first to retrieve the argument.
    const Point p = yio_printctx_va_arg(t, Point);
    // Then it must check yio_printctx_init and return if it fails.
    int ret = yio_printctx_init(t);
    if (ret) return ret;
    // Finally, use yio_printctx_printf for the actual output.
    return yio_printctx_printf(t, "Point(x={}, y={})", p.x, p.y);
}

int main(void) {
    // 1. Basic printing using yio_println
    // Yio automatically handles basic types and adds a newline.
    yio_println("Welcome to Yio Iconic Output!");
    yio_println("Integer: {}, Hex: {:#x}, Float: {:.2f}", 42, 255, 3.14159);

    // 2. Custom type printing via callback.
    // yio_callback() wraps the pointer and callback into a formatable object.
    Point p = {10, 20};
    yio_println("Custom object printing: {}", yio_callback(print_point, p));

    // 3. Conditional f-string printing (requires Yio GCC/Clang plugin).
    // The plugin validates format strings at compile-time and optimizes them.
#if YIO_HAS_FSTRING
    yio_println_f("F-string: point is at {p.x},{p.y}");
#endif

    return 0;
}
