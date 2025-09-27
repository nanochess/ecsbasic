# ECS extended BASIC

## by Oscar Toledo G. https://nanochess.org/

### (c) Copyright 2025 Oscar Toledo G.

This a BASIC language for the Intellivision Entertainment Computer System. I intend to make it as a (better) replacement for the incredibly slow Intellivision ECS BASIC.

It is written in CP1610 assembler language, and it only has been tested in emulation.

For example, this program runs in 15 seconds (modified from a benchmark by carlsson):

![image](shot0006.gif)

The same program for the Mattel ECS BASIC takes 210 seconds:

![image](shot0005.gif)

The resulting value is meaningless because the calculations exceed completely the floating-point precision.

There's no roadmap currently, and so far I've only implemented a core BASIC language.

There are 26 variables (A-Z), and 26 arrays (A-Z) that require DIM first to declare them.

The floating-point support is 25-bit mantissa, 7-bit exponent, and sign.

The following statements are supported:

    LIST
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

