#ECS extended BASIC

##by Oscar Toledo G. https://nanochess.org/

###(c) Copyright 2025 Oscar Toledo G.

This a BASIC language for the Intellivision Entertainment Computer System. I intend to make it as a (better) replacement for the incredibly slow Intellivision ECS BASIC.

It is written in CP1610 assembler language, and it only has been tested in emulation.

For example this program:

    10 I=1
    20 A=A+I
    30 A=A*I
    40 I=I+1
    50 IF I<1001 THEN 20
    60 PRINT A

Takes 15 seconds to execute with my BASIC language. And in the ECS BASIC it takes around 200 seconds.

![image](shot0004.gif)

There's no roadmap currently, and so far I've only implemented a core BASIC language. There are 26 variables (A-Z). The floating-point support is 25-bit mantissa, 7-bit exponent, and sign.

The following statements are supported:

    LIST
    RUN
    NEW
    v = expr
    IF expr THEN line
    IF expr THEN statement
    INPUT v
    INPUT "string";v
    PRINT expr
    PRINT "string"
    PRINT "string";expr

The following expression operators are supported:

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
    (expr)
    num
    v

Currently, the number input only allows for 16-bit integers, that are translated to floating-point. However, the number output is able to show fractions, and exponents.
