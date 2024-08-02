#!/bin/sh

if (iverilog -g2005-sv -DICARUS=1 -o icarus_qqq icarus.v processor.v)
then

    vvp icarus_qqq >> /dev/null

    # gtkwave icarus_result.vcd
    echo "OK"
    
fi
