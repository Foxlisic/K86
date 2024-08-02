#include <stdio.h>

// Создать таблицу четности (lookup)
int main(int argc, char* argv[]) {

    int i;

    for (i = 0; i < 256; i++) {

        int a = (i & 0xf) ^ ((i >> 4) & 0xf);
        a = (a & 3) ^ ((a >> 2) & 3);
        a = (a & 1) ^ ((a >> 1) & 1) ^ 1;

        if ((i % 16) == 0) printf("\n");
        printf("%d, ", a);
    }

}
