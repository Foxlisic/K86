#include "obj_dir/Vcore.h"

#include "i386.h"
#include "charmap.h"
#include "i386.cpp"
#include "i386_dasm.cpp"

int main(int argc, char** argv)
{
    return (new i386(argc, argv))->main();
}
