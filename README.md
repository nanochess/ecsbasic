# ECS extended BASIC

## by Oscar Toledo G. https://nanochess.org/

### (c) Copyright 2025 Oscar Toledo G.

This a BASIC language for the Intellivision Entertainment Computer System. I intend to make it as a (better) replacement for the incredibly slow Intellivision ECS BASIC.

It is written in CP1610 assembler language, and it has been tested both in emulation and with real hardware.

For example, this program runs in 15 seconds (modified from a benchmark by carlsson):

![image](shot0006.gif)

The same program for the Mattel ECS BASIC takes 210 seconds:

![image](shot0005.gif)

The resulting value of this benchmark is meaningless, because the calculations exceed completely the floating-point precision.

There's no roadmap currently, and so far I've only implemented a numeric BASIC language (no string support, except for fixed strings in PRINT)

There are 26 variables (A-Z), and 26 arrays (A-Z) that require DIM first to declare them.

The floating-point support is 25-bit mantissa, 7-bit exponent, and sign.

The following statements are supported:
    
    LIST
    LIST line
    LIST line-
    LIST line-line
    RUN
    NEW
    REM comment
    DIM a(length)
    v = expr
    IF expr THEN line
    IF expr THEN statement
    INPUT v
    INPUT "string";v
    PRINT expr
    PRINT "string"
    PRINT "string";expr
    GOSUB line
    RETURN
    FOR v=x TO y
    FOR v=x TO y STEP z
    NEXT
    NEXT v
    RESTORE
    RESTORE line
    READ a
    READ a,b
    DATA v
    DATA v,v
    COLOR v
    SPRITE [0-7],x,y,c
    SOUND 0,[f][,v]
    SOUND 1,[f][,v]
    SOUND 2,[f][,v]
    SOUND 3,[f][,env]
    SOUND 4,[noise][,mix]
    WAIT     
    bk(pos)=card   
    MODE 0,colors
    MODE 1
    BORDER color
    DEFINE card,"hex.drawing"

Statements can be concatenated on a single line using the colon as a separator.

The following expression operators are supported:

    OR
    XOR
    AND
    =
    <>
    <
    >
    <=
    >=
    +
    -
    *
    /
    -expr
    NOT expr
    (expr)
    num
    v
    a(index)
    INT(expr)
    ABS(expr)
    SGN(expr)
    RND
    STICK(cont)
    STRIG(cont)
    KEY(cont)
    BK(pos)

Currently, the number input only allows for 16-bit integers, that are translated to floating-point. However, the number output is able to show fractions, and exponents.

![image](shot0004.gif)

A small game in this flavor of BASIC:

    10 CLS:REM UFO INVASION. NANOCHESS 2025
    20 DEFINE 0,"183C00FF007E3C000018183C3C7E7E000000183C3C3C3C7EFF2400"
    50 x=96:w=0:v=0:u=0:t=159
    60 SPRITE 0,776+x,344,2061
    70 SPRITE 1,776+v,256+w,2066
    80 SPRITE 2,1796+t,256+u,6149
    90 WAIT:c=STICK(0)
    100 IF c>=3 AND c<=7 THEN IF x<152 THEN x=x+4
    110 IF c>=11 AND c<=15 THEN IF x>0 THEN x=x-4
    120 IF w=0 THEN SOUND 2,,0:IF STRIG(0) THEN v=x:w=88
    130 t=t+5:IF t>=160 THEN t=0:u=INT(RND*32)+8
    140 IF w THEN SOUND 2,w+20,12:w=w-4:IF ABS(w-u)<8 AND ABS(v-t)<8 THEN t=164:w=0:SOUND 3,8000,9:SOUND 1,2048,48
    150 GOTO 60
