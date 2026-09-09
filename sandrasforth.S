# rax - top-of-stack, syscall number.
# rbx - working register.
# rcx - temporary, syscall scratch.
# rdx - temporary, syscall argument.

# rsi - syscall argument.
# rdi - syscall argument.
# rbp - data   stack pointer.
# rsp - return stack pointer.

# r8  - unused, syscall argument.
# r9  - unused, syscall argument.
# r10 - unused, syscall argument.
# r11 - unused, syscall scratch.

# r12 - threaded code pointer.
# r13 - unused.
# r14 - unused.
# r15 - unused.

.set CELL, 8
.set LATEST, 0
.set IMMEDIATE, (1 << 7)

.macro DUP # x -- x x
	subq $CELL, %rbp
	movq %rax, (%rbp)
.endm

.macro NIP # x1 x2 -- x2
	leaq CELL(%rbp), %rbp
.endm

.macro TWONIP # x1 x2 x3 -- x3
	addq $CELL * 2, %rbp
.endm

.macro DROP # x --
	movq (%rbp), %rax
	NIP
.endm

.macro TWODROP # x1 x2 --
	movq CELL(%rbp), %rax
	TWONIP
.endm

.macro NEXT
	movq (%r12), %rbx
	addq $CELL, %r12

	jmp *(%rbx)
.endm

.macro DEFINE body, name, flags=0
head_\body:
	.quad LATEST
	.set LATEST, head_\body
	.byte (1f - 0f) | \flags

0:
	.ascii "\name"

1:

.align CELL

\body:
.endm

.macro DEFCODE body, name
DEFINE \body, "\name"
	.quad code_\body
.endm

.macro DEFWORD body, name, flags=0
DEFINE \body, "\name", \flags
	.quad code_enter
.endm

.macro DEFCONST body, name, val
DEFWORD \body, "\name"
	.quad lit, \val

	.quad exit
.endm

.macro DEFVAR body, name, val
var_\body:
	.quad \val

DEFWORD \body, "\name"
	.quad lit, var_\body

	.quad exit
.endm

.text

.global _start

_start:
	movl $dstack, %ebp
	movl $main, %r12d

	NEXT

code_enter:
	pushq %r12
	addq $CELL, %rbx
	movq %rbx, %r12

	NEXT

code_branch:
	movq (%r12), %r12

	NEXT

code_zbranch: # x --
	testq %rax, %rax
	DROP

	jz code_branch

	addq $CELL, %r12

	NEXT

code_execute: # addr --
	movq %rax, %rbx
	DROP

	jmp *(%rbx)

code_exit:
	popq %r12

	NEXT

code_lit: # -- x
	DUP
	movq (%r12), %rax
	addq $CELL, %r12

	NEXT

code_dup: # x -- x x
	DUP

	NEXT

code_nip: # x1 x2 -- x2
	NIP

	NEXT

code_twonip: # x1 x2 x3 -- x3
	TWONIP

	NEXT

code_drop: # x --
	DROP

	NEXT

code_twodrop: # x1 x2 --
	TWODROP

	NEXT

code_over: # x1 x2 -- x1 x2 x1
	DUP
	movq CELL(%rbp), %rax

	NEXT

code_rpush: # x --
	pushq %rax
	DROP

	NEXT

code_rpull: # -- x
	DUP
	popq %rax

	NEXT

code_invert: # x1 -- x2
	notq %rax

	NEXT

code_twomul: # x1 -- x2
	shlq %rax

	NEXT

code_twodiv: # x1 -- x2
	shrq %rax

	NEXT

code_lshift: # x1 u -- x2
	movb %al, %cl
	DROP
	shlq %cl, %rax

	NEXT

code_rshift: # x1 u -- x2
	movb %al, %cl
	DROP
	shrq %cl, %rax

	NEXT

code_and: # x1 x2 -- x3
	andq (%rbp), %rax
	NIP

	NEXT

code_or: # x1 x2 -- x3
	orq (%rbp), %rax
	NIP

	NEXT

code_xor: # x1 x2 -- x3
	xorq (%rbp), %rax
	NIP

	NEXT

code_negate: # n1 -- n2
	negq %rax

	NEXT

code_inc: # n1 -- n2
	incq %rax

	NEXT

code_dec: # n1 -- n2
	decq %rax

	NEXT

code_add: # n1|u1 n2|u2 -- n3|u3
	addq %rax, (%rbp)
	DROP

	NEXT

code_sub: # n1|u1 n2|u2 -- n3|u3
	subq %rax, (%rbp)
	DROP

	NEXT

code_mul: # n1 n2 -- n3
	imulq (%rbp)
	NIP

	NEXT

code_ummul: # u1 u2 -- ud
	mulq (%rbp)
	movq %rax, (%rbp)
	movq %rdx, %rax

	NEXT

code_div: # n1 n2 -- n3
	movq %rax, %rcx
	movq (%rbp), %rax
	cqo
	idivq %rcx
	NIP

	NEXT

code_divmod: # n1 n2 -- n3 n4
	movq %rax, %rcx
	movq (%rbp), %rax
	cqo
	idivq %rcx
	movq %rdx, (%rbp)

	NEXT

code_umdivmod: # ud u1 -- u2 u3
	movq %rax, %rcx
	movq (%rbp), %rdx
	NIP
	movq (%rbp), %rax
	divq %rcx
	movq %rdx, (%rbp)

	NEXT

code_fetch: # addr -- x
	movq (%rax), %rax

	NEXT

code_store: # x addr --
	movq (%rbp), %rdx
	movq %rdx, (%rax)
	TWODROP

	NEXT

code_cfetch: # addr -- char
	movzbq (%rax), %rax

	NEXT

code_cstore: # char addr --
	movb (%rbp), %dl
	movb %dl, (%rax)
	TWODROP

	NEXT

code_bye:
	movl $60, %eax # SYS_exit.
	xorl %edi, %edi # Error code.

	syscall

code_key: # -- char
	DUP
	xorl %eax, %eax # SYS_read.
	movl $1, %edx # Count.
	pushq $0
	movq %rsp, %rsi # Destination.
	xorl %edi, %edi # STDIN.

	syscall

	testq %rax, %rax

	jz code_bye

	popq %rax

	NEXT

code_emit: # char --
	pushq %rax
	movl $1, %eax # SYS_write.
	movl $1, %edx # Count.
	movq %rsp, %rsi # Source.
	movl $1, %edi # STDOUT.

	syscall

	popq %rax
	DROP

	NEXT

.align 0x40

DEFCODE enter,    "enter"
DEFCODE branch,   "branch"
DEFCODE zbranch,  "0branch"
DEFCODE execute,  "execute"
DEFCODE exit,     "exit"
DEFCODE lit,      "lit"
DEFCODE dup,      "dup"
DEFCODE nip,      "nip"
DEFCODE twonip,   "2nip"
DEFCODE drop,     "drop"
DEFCODE twodrop,  "2drop"
DEFCODE over,     "over"
DEFCODE rpush,    ">r"
DEFCODE rpull,    "r>"
DEFCODE invert,   "invert"
DEFCODE twomul,   "2*"
DEFCODE twodiv,   "2/"
DEFCODE lshift,   "lshift"
DEFCODE rshift,   "rshift"
DEFCODE and,      "and"
DEFCODE or,       "or"
DEFCODE xor,      "xor"
DEFCODE negate,   "negate"
DEFCODE inc,      "1+"
DEFCODE dec,      "1-"
DEFCODE add,      "+"
DEFCODE sub,      "-"
DEFCODE mul,      "*"
DEFCODE ummul,    "um*"
DEFCODE div,      "/"
DEFCODE divmod,   "/mod"
DEFCODE umdivmod, "um/mod"
DEFCODE fetch,    "@"
DEFCODE store,    "!"
DEFCODE cfetch,   "c@"
DEFCODE cstore,   "c!"
DEFCODE bye,      "bye"
DEFCODE key,      "key"
DEFCODE emit,     "emit"

DEFCONST cell,           "cell",           CELL       # -- u
DEFCONST lf,             "lf",             '\n'       # -- char
DEFCONST bl,             "bl",             ' '        # -- char
DEFCONST immediate_flag, "immediate-flag", IMMEDIATE  # -- x
DEFCONST tickinput,      "'input",         input      # -- addr
DEFCONST tickbuffer,     "'buffer",        buffer     # -- addr

.data

DEFVAR toin,    ">in",     0          # -- addr
DEFVAR state,   "state",   0          # -- addr
DEFVAR here,    "here",    vocabulary # -- addr
DEFVAR latest,  "latest",  head_main  # -- addr
DEFVAR current, "current", head_main  # -- addr
DEFVAR base,    "base",    10         # -- addr

DEFWORD twodup, "2dup" # x1 x2 -- x1 x2 x1 x2
	.quad over
	.quad over

	.quad exit

DEFWORD qdup, "?dup" # x -- 0 | x x
	.quad dup

	.quad zbranch, 0f

	.quad dup

0:
	.quad exit

DEFWORD flag, "flag" # x -- flag
	.quad zbranch, 0f

	.quad lit, -1

	.quad exit

0:
	.quad lit, 0

	.quad exit

DEFWORD zequals, "0=" # x -- flag
	.quad flag
	.quad invert

	.quad exit

DEFWORD equals, "=" # x1 x2 -- flag
	.quad xor
	.quad zequals

	.quad exit

DEFWORD zless, "0<" # n -- flag
	.quad lit, 1 << (CELL * 8 - 1)
	.quad and
	.quad flag

	.quad exit

DEFWORD less, "<" # n1 n2 -- flag
	.quad twodup
	.quad xor
	.quad zless

	.quad zbranch, 0f

	.quad drop
	.quad zless

	.quad exit

0:
	.quad sub
	.quad zless

	.quad exit

DEFWORD uless, "u<" # u1 u2 -- flag
	.quad twodup
	.quad xor
	.quad zless

	.quad zbranch, 0f

	.quad nip
	.quad zless

	.quad exit

0:
	.quad sub
	.quad zless

	.quad exit

DEFWORD min, "min" # n1 n2 -- n3
	.quad twodup
	.quad less

	.quad zbranch, 0f

	.quad drop

	.quad exit

0:
	.quad nip

	.quad exit

DEFWORD ccomma, "c," # char --
	.quad here
	.quad fetch
	.quad dup
	.quad inc
	.quad here
	.quad store
	.quad cstore

	.quad exit

DEFWORD comma, "," # x --
	.quad here
	.quad fetch
	.quad dup
	.quad cell
	.quad add
	.quad here
	.quad store
	.quad store

	.quad exit

DEFWORD aligned, "aligned" # x1 -- x2
	.quad lit, CELL - 1
	.quad add
	.quad lit, -CELL
	.quad and

	.quad exit

DEFWORD count, "count" # addr1 -- addr2 u
	.quad inc
	.quad dup
	.quad dec
	.quad cfetch

	.quad exit

DEFWORD cmove, "cmove" # addr1 addr2 u --
0:
	.quad qdup

	.quad zbranch, 0f

	.quad rpush
	.quad over
	.quad cfetch
	.quad over
	.quad cstore
	.quad rpush
	.quad inc
	.quad rpull
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad twodrop

	.quad exit

DEFWORD scomma, "s," # addr u --
	.quad dup
	.quad ccomma
	.quad dup
	.quad rpush
	.quad rpush
	.quad here
	.quad fetch
	.quad rpull
	.quad cmove
	.quad rpull
	.quad here
	.quad fetch
	.quad add
	.quad aligned
	.quad here
	.quad store

	.quad exit

DEFWORD sequals, "s=" # addr1 u1 addr2 u2 -- flag
	.quad rpush
	.quad over
	.quad rpush
	.quad nip
	.quad rpull
	.quad rpull
	.quad over
	.quad equals

	.quad zbranch, 1f

0:
	.quad dup
	.quad rpush
	.quad rpush
	.quad over
	.quad cfetch
	.quad over
	.quad cfetch
	.quad equals
	.quad rpull
	.quad and

	.quad zbranch, 0f

	.quad rpush
	.quad inc
	.quad rpull
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad rpull
	.quad nip
	.quad nip
	.quad zequals

	.quad exit

1:
	.quad twonip
	.quad drop
	.quad lit, 0

	.quad exit

DEFWORD refill, "refill"
	.quad lit, 0
	.quad tickinput
	.quad cstore
	.quad lit, 0
	.quad toin
	.quad store

0:
	.quad key
	.quad dup
	.quad dup
	.quad lf
	.quad equals

	.quad zbranch, 1f

	.quad drop
	.quad bl

1:
	.quad tickinput
	.quad count
	.quad add
	.quad cstore
	.quad tickinput
	.quad cfetch
	.quad inc
	.quad tickinput
	.quad cstore
	.quad lf
	.quad equals
	.quad tickinput
	.quad cfetch
	.quad lit, 0xFF
	.quad equals
	.quad or

	.quad zbranch, 0b

	.quad exit

DEFWORD type, "type" # addr u --
0:
	.quad qdup

	.quad zbranch, 0f

	.quad rpush
	.quad dup
	.quad cfetch
	.quad emit
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad drop

	.quad exit

DEFWORD parse, "parse" # char -- addr u
	.quad rpush
	.quad toin
	.quad fetch
	.quad dup

0:
	.quad dup
	.quad tickinput
	.quad cfetch
	.quad uless
	.quad over
	.quad lit, input + 1
	.quad add
	.quad cfetch
	.quad rpull
	.quad dup
	.quad rpush
	.quad equals
	.quad invert
	.quad and

	.quad zbranch, 0f

	.quad inc

	.quad branch, 0b

0:
	.quad rpull
	.quad drop
	.quad dup
	.quad inc
	.quad toin
	.quad store
	.quad over
	.quad sub
	.quad rpush
	.quad lit, input + 1
	.quad add
	.quad rpull

	.quad exit

DEFWORD word, "word" # char -- addr
	.quad rpush
	.quad toin
	.quad fetch

0:
	.quad dup
	.quad tickinput
	.quad cfetch
	.quad uless
	.quad over
	.quad lit, input + 1
	.quad add
	.quad cfetch
	.quad rpull
	.quad dup
	.quad rpush
	.quad equals
	.quad and

	.quad zbranch, 0f

	.quad inc

	.quad branch, 0b

0:
	.quad toin
	.quad store
	.quad tickbuffer
	.quad rpull
	.quad parse
	.quad lit, IMMEDIATE - 1
	.quad min
	.quad rpush
	.quad over
	.quad rpull
	.quad over
	.quad cstore
	.quad count
	.quad cmove

	.quad exit

DEFWORD ctonumber, "c>number" # char -- n
	.quad lit, '0'
	.quad sub
	.quad lit, 9
	.quad over
	.quad less

	.quad zbranch, 0f

	.quad lit, 'A' - '0' - 10
	.quad sub
	.quad dup
	.quad lit, 10
	.quad less
	.quad or

0:
	.quad exit

DEFWORD utonumber, "u>number" # 0 addr1 u1 -- u2 addr2 u3
0:
	.quad dup
	.quad rpush
	.quad rpush
	.quad dup
	.quad rpush
	.quad cfetch
	.quad ctonumber
	.quad rpull
	.quad over
	.quad base
	.quad fetch
	.quad uless
	.quad rpull
	.quad and

	.quad zbranch, 0f

	.quad rpush
	.quad rpush
	.quad base
	.quad fetch
	.quad mul
	.quad rpull
	.quad add
	.quad rpull
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad nip
	.quad rpull

	.quad exit

DEFWORD tonumber, ">number" # 0 addr1 u1 -- n addr2 u2
	.quad over
	.quad cfetch
	.quad lit, '-'
	.quad equals

	.quad zbranch, 0f

	.quad rpush
	.quad inc
	.quad rpull
	.quad dec
	.quad utonumber
	.quad rpush
	.quad rpush
	.quad negate
	.quad rpull
	.quad rpull

	.quad branch, 1f

0:
	.quad utonumber

1:
	.quad exit

DEFWORD tocode, ">code" # addr1 -- addr2
	.quad cell
	.quad add
	.quad count
	.quad lit, IMMEDIATE - 1
	.quad and
	.quad add
	.quad aligned

	.quad exit

DEFWORD find, "find" # addr -- addr 0 | xt 1 | xt -1
	.quad dup
	.quad latest
	.quad rpush

0:
	.quad rpull
	.quad fetch
	.quad dup
	.quad rpush
	.quad zequals
	.quad dup
	.quad invert

	.quad zbranch, 1f

	.quad drop
	.quad dup
	.quad count
	.quad rpull
	.quad dup
	.quad rpush
	.quad cell
	.quad add
	.quad count
	.quad lit, IMMEDIATE - 1
	.quad and
	.quad sequals

1:
	.quad zbranch, 0b

	.quad drop
	.quad rpull
	.quad dup

	.quad zbranch, 0f

	.quad nip
	.quad dup
	.quad cell
	.quad add
	.quad cfetch
	.quad immediate_flag
	.quad and
	.quad state
	.quad fetch
	.quad invert
	.quad or

	.quad zbranch, 1f

	.quad lit, 1

	.quad branch, 2f

1:
	.quad lit, -1

2:
	.quad rpush
	.quad tocode
	.quad rpull

0:
	.quad exit

DEFWORD lbracket, "[", IMMEDIATE
	.quad lit, 0
	.quad state
	.quad store

	.quad exit

DEFWORD rbracket, "]"
	.quad lit, -1
	.quad state
	.quad store

	.quad exit

DEFWORD colon, ":"
	.quad here
	.quad fetch
	.quad current
	.quad store
	.quad latest
	.quad fetch
	.quad comma
	.quad bl
	.quad word
	.quad count
	.quad scomma
	.quad lit, code_enter
	.quad comma
	.quad rbracket

	.quad exit

DEFWORD reveal, "reveal"
	.quad current
	.quad fetch
	.quad latest
	.quad store

	.quad exit

DEFWORD semicolon, ";", IMMEDIATE
	.quad lit, exit
	.quad comma
	.quad reveal
	.quad lbracket

	.quad exit

DEFWORD tick, "'" # -- 0 | xt
	.quad bl
	.quad word
	.quad find
	.quad dup

	.quad zbranch, 0f

	.quad drop
	.quad exit

0:
	.quad nip

	.quad exit

DEFWORD literal, "literal", IMMEDIATE # x --
	.quad lit, lit
	.quad comma
	.quad comma

	.quad exit

DEFWORD interpret, "interpret"
0:
	.quad bl
	.quad word
	.quad dup
	.quad cfetch

	.quad zbranch, 4f

	.quad find
	.quad qdup

	.quad zbranch, 3f

	.quad zless

	.quad zbranch, 1f

	.quad comma

	.quad branch, 2f

1:
	.quad execute

2:
	.quad branch, 2f

3:
	.quad lit, 0
	.quad over
	.quad count
	.quad tonumber
	.quad nip

	.quad zbranch, 1f

	.quad drop
	.quad count
	.quad type
	.quad lit, '?'
	.quad emit

	.quad branch, 2f

1:
	.quad nip
	.quad state
	.quad fetch

	.quad zbranch, 2f

	.quad literal

2:
	.quad branch, 0b

4:
	.quad drop

	.quad exit

DEFINE main, "main"
	.quad refill
	.quad interpret

	.quad branch, main

.bss

.align 0x40

input:
	.skip 0x100

buffer:
	.skip 0x100

	.skip 0x1000
dstack:

vocabulary:
	.skip 0x3000
