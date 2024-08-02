cd bios && sh make.sh && cd ..
if (gcc -Wall -Os main.c -o main) then
    ./main
fi
