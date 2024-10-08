#include "obj_dir/Vcore.h"
#include "font.h"
#include "tb.h"

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);
    TB* tb = new TB(argc, argv);
    while (tb->main());
    return tb->destroy();
}
