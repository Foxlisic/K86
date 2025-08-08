#include "i386.h"
#include "charmap.h"
#include "i386.cpp"

int main(int argc, char** argv)
{
    return (new i386(argc, argv))->main();
}
