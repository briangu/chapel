//_extern proc printf(fmt: string, vals...?numvals): int;
_extern proc printf(fmt: string, val1, val2, val3, val4): int;

var x = 12.34;

printf("%e %f %g %14.14f\n", x, x, x, x);
