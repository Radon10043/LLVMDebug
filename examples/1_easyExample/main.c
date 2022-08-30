#include <stdio.h>

void func1() {
  printf("Hello world.");
}

int func2(int x, int y) {
  return x + y;
}

int main(int argc, char** argv) {
  int a = 1, b = 2;

  func1();
  int c = func2(a, b);

  return 0;
}