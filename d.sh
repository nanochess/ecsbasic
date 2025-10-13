../jzintv/bin/as1600 -o basic.bin -l basic.lst basic.asm
../jzintv/bin/jzintv -v1 -s1 -z1 --ecs-printer=printer.txt --ecs-tape=tape#.ecs basic.bin
