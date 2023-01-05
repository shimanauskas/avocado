: [ top @ here ! -1 state ! ; immediate
: ] postpone apply 0 state ! ; immediate

: begin top @ ; immediate

: if lit ?jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit ?jump postpone , postpone , ; immediate

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate

: char word [ 'buffer 1+ ] literal b@ ; immediate

: ( begin word? [ 'buffer ] literal b@ 1 =
  [ 'buffer 1+ ] literal b@ char ) literal = and until ; immediate

: b, ( byte -- ) top @ dup 1+ top ! b! collision ; immediate

: " ( -- addr ) top @ 0 postpone b,
  begin skip key? not if accept repeat
  begin
    key advance dup char " literal xor
  if
    postpone b, key? not if accept then
  repeat
  drop top @ over 1+ - over b! top @ aligned top ! postpone commit ; immediate

: hold ( char -- ) [ 'buffer ] literal @ 1- dup [ 'buffer ] literal ! b! ;

: digit ( u -- char ) dup 10 u<
  if char 0 literal + tail then [ char A 10 - ] literal + ;

: u. ( u -- ) [ 'buffer 256 + ] literal [ 'buffer ] literal !
  begin 0 base @ um/mod push digit hold pop dup 0= until drop
  [ 'buffer ] literal @ [ 'buffer 256 + ] literal over - type ;

: . ( n -- ) dup 0< if char - literal emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate

: lshift ( x1 u -- x2 ) begin dup if push 2* pop 1- repeat drop ;

: rshift ( x1 u -- x2 ) begin dup if push 2/ pop 1- repeat drop ;

: space 32 emit ;

: * ( n1 n2 -- n3 ) um* drop ;

: cells ( n1 -- n2 ) [ cell ] literal * ;

: stdin  0 ;
: stdout 1 ;

: bool ( x -- bool ) if -1 tail then 0 ;

: 0= ( x -- bool ) bool not ;

:  = ( x1 x2 -- bool ) xor 0= ;

: 0< ( n -- bool ) [ 1 8 cells 1- lshift ] literal and bool ;

:  < ( n1 n2 -- bool ) over over xor 0< if drop 0< tail then - 0< ;

: u< ( u1 u2 -- bool ) over over xor 0< if nip  0< tail then - 0< ;

: whithin ( u1 u2 u3 -- bool ) push over push u< not pop pop u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- not ] literal and ;

: string ( addr1 -- addr2 u ) dup push 1+ pop b@ ;

: bye flush 0 dup dup [ sys-exit ] literal syscall ( We never return. )

: accept [ stdin ] literal [ 'input 1+ ] literal 255 [ sys-read ] literal
  syscall dup ?jump ' bye ,
  [ 'input ] literal b! [ 'input 1+ ] literal mark ! ;

: key? ( -- bool ) mark @ [ 'input ] literal string + u< ;
: key  ( -- char ) mark @ b@ ;

: advance mark @ 1+ mark ! ;

: flush [ stdout ] literal [ 'output ] literal string [ sys-write ] literal
  syscall drop 0 [ 'output ] literal b! ;
