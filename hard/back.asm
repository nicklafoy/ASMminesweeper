
%include "/usr/local/share/csc314/asm_io.inc"

; how frequently we check for input
; 1,000,000 = 1 second
%define TICK 100000	; 1/10th of a second

; the file that stores the initial state
%define BOARD_FILE 'board.txt'
%define SECRET_BOARD 'gameboard.txt'

; how to represent everything
%define WALL_CHAR '#'
%define PLAYER_CHAR 'O'
%define EMPTY_CHAR ' '
%define FLAG_CHAR '^'
%define BOMB_CHAR '*'


; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH 40

; the player starting position.
; top left is considered (0,0)
%define STARTX 1
%define STARTY 1

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define ENTERCHAR 'k'
%define SPACECHAR 32

segment .data

	; used to fopen() the board file defined above
	board_file			db BOARD_FILE,0
	game_board_file 	db SECRET_BOARD,0
	; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; called by system() to clear/refresh the screen
	clear_screen_cmd	db "clear",0

	; things the program will print
	help_str			db 13,10,"Controls: ", \
							UPCHAR,"=UP / ", \
							LEFTCHAR,"=LEFT / ", \
							DOWNCHAR,"=DOWN / ", \
							RIGHTCHAR,"=RIGHT / ", \
							ENTERCHAR,"=SELECT / ", \
							"SPACEBAR=FLAG / ", \
							EXITCHAR,"=EXIT",10, \
							13,10,"NOTES:",13,10,"  ---If the game is frozen, it is doing work behind the scenes so give it a minute...",13,10,"  ---If it takes a long while restart the game...",13,10,"  ---Also, if there are ~ that you know should be numbers, select a blank spot again...",13,10,10,"  ---To win, you must flag every bomb, and if you flag a spot that is not a bomb it will",13,10,"     count against you. So make sure you flag only bombs. You can unflag a flag by flagging the spot again.", \
							13,10,10,0

	fmt					db	"%d",10,0
	bomb_str			db	"Bombs: %d",13,10,10,0
	win_str				db	10,"You flagged all the bombs! You win!",13,10,0
	lose_str			db	10,"Sorry you selected a bomb!",13,10,0
	res_str				db	10,"Would you like to play again? 'y' for yes, 'n' for no",13,10,0
segment .bss

	; this array stores the current rendered gameboard (HxW)
	board		resb	(HEIGHT * WIDTH)
	gameboard	resb 	(HEIGHT * WIDTH)

	; these variables store the current player position
	xpos	resd	1
	ypos	resd	1

	bombcount resd	1
	score	resd	1

segment .text

	global	asm_main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render

	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose
	extern 	usleep
	extern 	fcntl

asm_main:
	push	ebp
	mov		ebp, esp

	;***************CODE STARTS HERE***************************

	sub 	esp, 16
	mov 	dword[ebp-8], 55555555

	; put the terminal in raw mode so the game works nicely
	start_again:
	call	raw_mode_on

	; read the game board file into the global variable
	push	board
	push 	board_file
	call	init_board
	add 	esp, 8

	push	gameboard
	push 	game_board_file
	call 	init_board
	add 	esp, 8

	; set the player at the proper start position
	mov		dword[xpos], 2
	mov	 	dword[ypos], STARTY
	mov		dword[bombcount], 0
	mov		dword[score], 0

	set_game_board:
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		valid_spot

		add		dword[ypos], 1
		mov 	dword[xpos], 2
		jmp		set_game_board

	valid_spot:
		cmp		dword[xpos], 38
		jge		dont_set_bomb
		mov 	dword[ebp-4], eax
		rdrand	eax
		div 	dword[ebp-8]
		cmp		eax, 69
		jl		dont_set_bomb

		mov		eax, dword[ebp-4]
		mov 	byte[eax], BOMB_CHAR
		inc		dword[bombcount]

	dont_set_bomb:
		inc		dword[xpos]
		cmp		dword[xpos], 38
		jne		set_game_board
		cmp		dword[ypos], 17
		jne		set_game_board

	end_set_game_board:

	mov		dword[xpos], STARTX
	mov	 	dword[ypos], STARTY

	set_number:
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		valid_spot_for_number

		add		dword[ypos], 1
		mov 	dword[xpos], 1
		jmp		set_number

	valid_spot_for_number:
		cmp 	byte[eax], BOMB_CHAR
		jne		compare

	check_right:
		inc		dword[xpos]
		mov		eax, WIDTH
		mul		DWORD[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_right_end
		cmp		byte[eax], BOMB_CHAR
		je		dec_x

		inc		byte[eax]

			dec_x:
				dec		dword[xpos]

	check_bottom_right:
		inc		dword[xpos]
		inc		dword[ypos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_bottom_right_end
		cmp		byte[eax], BOMB_CHAR
		je		dec_x_dec_y

		inc		byte[eax]

			dec_x_dec_y:
				dec		dword[ypos]
				dec		dword[xpos]

	check_bottom:
		inc		dword[ypos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_bottom_end
		cmp		byte[eax], BOMB_CHAR
		je		dec_y

		inc		byte[eax]

			dec_y:
				dec		dword[ypos]

	check_bottom_left:
		dec 	dword[xpos]
		inc		dword[ypos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_bottom_left_end
		cmp		byte[eax], BOMB_CHAR
		je		inc_x_dec_y

		inc 	byte[eax]

			inc_x_dec_y:
				inc		dword[xpos]
				dec		dword[ypos]

	check_left:
		dec		dword[xpos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_left_end
		cmp		byte[eax], BOMB_CHAR
		je		inc_x

		inc 	byte[eax]

			inc_x:
				inc		dword[xpos]

	check_upper_left:
		dec		dword[xpos]
		dec		dword[ypos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_upper_left_end
		cmp		byte[eax], BOMB_CHAR
		je		inc_x_inc_y

		inc		byte[eax]

			inc_x_inc_y:
				inc 	dword[xpos]
				inc		dword[ypos]

	check_up:
		dec 	dword[ypos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_up_end
		cmp		byte[eax], BOMB_CHAR
		je		inc_y

		inc 	byte[eax]

			inc_y:
				inc 	dword[ypos]

	check_upper_right:
		dec		dword[ypos]
		inc		dword[xpos]
		mov		eax, WIDTH
		mul		dword[ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]

		cmp		byte[eax], WALL_CHAR
		je		check_upper_right_end
		cmp		byte[eax], BOMB_CHAR
		je		inc_y_dec_x

		inc		byte[eax]

			inc_y_dec_x:
				inc 	dword[ypos]
				dec		dword[xpos]

	jmp		compare


	check_right_end:
		dec		dword[xpos]
		jmp 	compare

	check_bottom_right_end:
		dec		dword[xpos]
		dec		dword[ypos]
		jmp		compare

	check_bottom_end:
		dec		dword[ypos]
		jmp		compare

	check_bottom_left_end:
		inc		dword[xpos]
		dec		dword[ypos]
		jmp		compare

	check_left_end:
		inc		dword[xpos]
		jmp 	compare

	check_upper_left_end:
		inc		dword[xpos]
		inc		dword[ypos]
		jmp 	compare

	check_up_end:
		inc		dword[ypos]
		jmp		compare

	check_upper_right_end:
		dec 	dword[xpos]
		inc		dword[ypos]
		jmp		compare

	compare:
		inc		dword[xpos]
		cmp		dword[xpos], 39
		jne		set_number
		cmp		dword[ypos], 18
		jne		set_number

	end_set_number:

	mov		dword[xpos], STARTX
	mov	 	dword[ypos], STARTY

	game_loop:

		push	TICK
		call 	usleep
		add 	esp, 4

		; draw the game board
		push	board
		call	render
		add		esp, 4

;		push	gameboard
;		call	render
;		add		esp, 4

		; get an action from the user
		call 	nonblocking_getchar
		cmp 	al, -1
		je 		game_loop

		; store the current position
		; we will test if the new position is legal
		; if not, we will restore these
		mov		esi, [xpos]
		mov		edi, [ypos]

		; choose what to do
		cmp		eax, EXITCHAR
		je		game_loop_end
		cmp		eax, UPCHAR
		je 		move_up
		cmp		eax, LEFTCHAR
		je		move_left
		cmp		eax, DOWNCHAR
		je		move_down
		cmp		eax, RIGHTCHAR
		je		move_right
		cmp 	eax, ENTERCHAR
		je		select_spot
		cmp		eax, SPACECHAR
		je		check_flag
		jmp		input_end			; or just do nothing

		select_spot:
			mov 	ebx, eax
			jmp		input_end
		check_flag:
			mov 	ebx, eax
			jmp		input_end
		; move the player according to the input character
		move_up:
			dec		DWORD [ypos]
			jmp		input_end
		move_left:
			dec		DWORD [xpos]
			jmp		input_end
		move_down:
			inc		DWORD [ypos]
			jmp		input_end
		move_right:
			inc		DWORD [xpos]
			jmp		input_end
		input_end:

		; (W * y) + x = pos

		; compare the current position to the wall character
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		valid_move

			; opps, that was an invalid move, reset
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi

		valid_move:

		cmp 	ebx, SPACECHAR
		je		flag
		cmp		ebx, ENTERCHAR
		je		recursive_box
		jmp		end_func
		flag:
			cmp		byte[eax], FLAG_CHAR
			jne 	put_flag
			mov 	byte[eax], '~'
			mov 	eax, WIDTH
			mul		dword[ypos]
			add		eax, [xpos]
			lea		eax, [gameboard + eax]
			cmp		byte[eax], BOMB_CHAR
			jne		inc_score
			dec		dword[score]
			jmp		end_func
			inc_score:
				inc		dword[score]
				mov 	eax, dword[bombcount]
				cmp		dword[score], eax
				jge		game_loop_end_win
				jmp 	end_func

			put_flag:
				mov 	byte[eax], FLAG_CHAR
				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [gameboard + eax]
				cmp		byte[eax], BOMB_CHAR
				jne		dec_score
				inc		dword[score]
				mov 	eax, dword[bombcount]
				cmp		dword[score], eax
				jge		game_loop_end_win
				jmp 	end_func
				dec_score:
					dec		dword[score]
					mov 	eax, dword[bombcount]
					cmp		dword[score], eax
					jge		game_loop_end_win
					jmp 	end_func

		recursive_box:
			mov 	eax, WIDTH
			mul		dword[ypos]
			add		eax, [xpos]
			lea		eax, [gameboard + eax]

			cmp		byte[eax], BOMB_CHAR
			je		game_loop_end_lose


			call	recursive_func1
			call 	recursive_func2
			call	recursive_func3


			mov 	eax, WIDTH
			mul		dword[ypos]
			add		eax, [xpos]
			lea		eax, [gameboard + eax]

			cmp		byte[eax], '0'
			jne		end_func

			mov		eax, dword[xpos]
			mov		dword[ebp-12], eax
			mov		eax, dword[ypos]
			mov		dword[ebp-16], eax

			mov		dword[xpos], STARTX
			mov		dword[ypos], STARTY

			fix_board:
				mov		eax, WIDTH
				mul		DWORD [ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]
				cmp		BYTE [eax], WALL_CHAR
				jne		valid_space

				add		dword[ypos], 1
				mov 	dword[xpos], 1
				jmp		fix_board

			valid_space:
				cmp		byte[eax], ' '
				jne		end_fix
				call	recursive_func1
				call	recursive_func2
				call	recursive_func3

				end_fix:
				inc		dword[xpos]
				cmp		dword[xpos], 39
				jne		fix_board
				cmp		dword[ypos], 18
				jne		fix_board
				mov 	eax, dword[ebp-12]
				mov		dword[xpos], eax
				mov		eax, dword[ebp-16]
				mov		dword[ypos], eax

			mov		eax, dword[xpos]
			mov		dword[ebp-12], eax
			mov		eax, dword[ypos]
			mov		dword[ebp-16], eax

			mov		dword[xpos], STARTX
			mov		dword[ypos], STARTY

			fix_board2:
				mov		eax, WIDTH
				mul		DWORD [ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]
				cmp		BYTE [eax], WALL_CHAR
				jne		valid_space2

				add		dword[ypos], 1
				mov 	dword[xpos], 1
				jmp		fix_board2

			valid_space2:
				cmp		byte[eax], ' '
				jne		end_fix2
				call	recursive_func1
				call	recursive_func2
				call	recursive_func3

				end_fix2:
				inc		dword[xpos]
				cmp		dword[xpos], 39
				jne		fix_board2
				cmp		dword[ypos], 18
				jne		fix_board2
				mov 	eax, dword[ebp-12]
				mov		dword[xpos], eax
				mov		eax, dword[ebp-16]
				mov		dword[ypos], eax

	end_func:

	jmp		game_loop

	game_loop_end_win:

		mov		dword[xpos], STARTX
		mov		dword[ypos], STARTY

		final_board1:
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		valid_final_spot1

		add		dword[ypos], 1
		mov 	dword[xpos], 1
		jmp		final_board1

	valid_final_spot1:
		cmp		byte[eax], '0'
		jne		dont_print_final_space1
		mov		byte[eax], ' '

	dont_print_final_space1:
		inc		dword[xpos]
		cmp		dword[xpos], 39
		jne		final_board1
		cmp		dword[ypos], 18
		jne		final_board1

		push	gameboard
		call	render
		add		esp, 4

		push 	win_str
		call 	printf
		add 	esp, 4

		push	res_str
		call	printf
		add		esp, 4

		mov 	eax, 0

		call	getchar
		cmp		al, 'y'
		jne		game_loop_end
		jmp		start_again

	game_loop_end_lose:

		mov		dword[xpos], STARTX
		mov		dword[ypos], STARTY

		final_board2:
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [gameboard + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		valid_final_spot2

		add		dword[ypos], 1
		mov 	dword[xpos], 1
		jmp		final_board2

	valid_final_spot2:
		cmp		byte[eax], '0'
		jne		dont_print_final_space2
		mov		byte[eax], ' '

	dont_print_final_space2:
		inc		dword[xpos]
		cmp		dword[xpos], 39
		jne		final_board2
		cmp		dword[ypos], 18
		jne		final_board2

		push	gameboard
		call	render
		add		esp, 4

		push	lose_str
		call 	printf
		add		esp, 4

		push	res_str
		call	printf
		add		esp, 4

		mov 	eax, 0

		call	getchar
		cmp		al, 'y'
		jne		game_loop_end
		jmp		start_again

	game_loop_end:

	; restore old terminal functionality
	call raw_mode_off

	;***************CODE ENDS HERE*****************************
	mov		eax, 0
	mov 	esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
raw_mode_on:

	push	ebp
	mov		ebp, esp

	push	raw_mode_on_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
raw_mode_off:

	push	ebp
	mov		ebp, esp

	push	raw_mode_off_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
init_board:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	dword[ebp+8]
	call	fopen
	add		esp, 8
	mov		DWORD [ebp-4], eax


	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp-8], 0
	read_loop:
	cmp		DWORD [ebp-8], HEIGHT
	je		read_loop_end

		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp-8]
		mov 	ecx, dword[ebp+12]
		lea		ebx, [ecx + eax]

		; read the bytes into the buffer
		push	DWORD [ebp-4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp-4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp-8]
	jmp		read_loop
	read_loop_end:

	; close the open file handle
	push	DWORD [ebp-4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
render:

	push	ebp
	mov		ebp, esp

	; two ints, for two loop counters
	; ebp-4, ebp-8
	sub		esp, 8

	; clear the screen
	push	clear_screen_cmd
	call	system
	add		esp, 4

	; print the help information
	push	help_str
	call	printf
	add		esp, 4

	;print score
	push	dword[bombcount]
	push	bomb_str
	call	printf
	add 	esp, 8

	; outside loop by height
	; i.e. for(c=0; c<height; c++)
	mov		DWORD [ebp-4], 0
	y_loop_start:
	cmp		DWORD [ebp-4], HEIGHT
	je		y_loop_end

		; inside loop by width
		; i.e. for(c=0; c<width; c++)
		mov		DWORD [ebp-8], 0
		x_loop_start:
		cmp		DWORD [ebp-8], WIDTH
		je 		x_loop_end

			; check if (xpos,ypos)=(x,y)
			mov		eax, [xpos]
			cmp		eax, DWORD [ebp-8]
			jne		print_board
			mov		eax, [ypos]
			cmp		eax, DWORD [ebp-4]
			jne		print_board
				; if both were equal, print the player
				push	PLAYER_CHAR
				jmp		print_end
			print_board:
				; otherwise print whatever's in the buffer
				mov		eax, [ebp-4]
				mov		ebx, WIDTH
				mul		ebx
				add		eax, [ebp-8]
				mov		ebx, 0
				mov		ecx, dword[ebp+8]
				mov		bl, BYTE [ecx + eax]
				push	ebx
			print_end:
			call	putchar
			add		esp, 4

		inc		DWORD [ebp-8]
		jmp		x_loop_start
		x_loop_end:

		; write a carriage return (necessary when in raw mode)
		push	0x0d
		call 	putchar
		add		esp, 4

		; write a newline
		push	0x0a
		call	putchar
		add		esp, 4

	inc		DWORD [ebp-4]
	jmp		y_loop_start
	y_loop_end:

	mov		esp, ebp
	pop		ebp
	ret

nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

	push	ebp
	mov		ebp, esp

	; single int used to hold flags
	; single character (aligned to 4 bytes) return
	sub		esp, 8

	; get current stdin flags
	; flags = fcntl(stdin, F_GETFL, 0)
	push	0
	push	F_GETFL
	push	STDIN
	call	fcntl
	add		esp, 12
	mov		DWORD [ebp-4], eax

	; set non-blocking mode on stdin
	; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
	or		DWORD [ebp-4], O_NONBLOCK
	push	DWORD [ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	call	getchar
	mov		DWORD [ebp-8], eax

	; restore blocking mode
	; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
	xor		DWORD [ebp-4], O_NONBLOCK
	push	DWORD [ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	mov		eax, DWORD [ebp-8]

	mov		esp, ebp
	pop		ebp
	ret

recursive_func1:
	push	ebp
	mov		ebp, esp

	sub		esp, 8
	mov		eax, dword[xpos]
	mov		dword[ebp-4], eax
	mov		eax, dword[ypos]
	mov		dword[ebp-8], eax

	mov 	eax, WIDTH
	mul		dword[ypos]
	add		eax, [xpos]
	lea		eax, [gameboard + eax]


	cmp		byte[eax], '#'
	je		recursive_end1
	cmp		byte[eax], '0'
	je		print_space_on_board_1
	cmp		byte[eax], '1'
	je		print_number_on_board1_1
	cmp		byte[eax], '2'
	je		print_number_on_board2_1
	cmp		byte[eax], '3'
	je		print_number_on_board3_1
	cmp		byte[eax], '4'
	je		print_number_on_board4_1
	cmp		byte[eax], '5'
	je		print_number_on_board5_1
	cmp		byte[eax], '6'
	je		print_number_on_board6_1
	cmp		byte[eax], '7'
	je		print_number_on_board7_1
	cmp		byte[eax], '8'
	je		print_number_on_board8_1
	cmp		byte[eax], '*'
	je		print_bomb_on_board_1
	jmp		recursive_end1

			print_space_on_board_1:
				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], ' '
			;right
				inc		dword[xpos]
				call	recursive_func1
				dec		dword[xpos]
			;bottomright
				inc		dword[xpos]
				inc		dword[ypos]
				call	recursive_func1
				dec		dword[xpos]
				dec		dword[ypos]
			;bottom
				inc		dword[ypos]
				call	recursive_func1
				dec 	dword[ypos]
				jmp recursive_end1
			print_number_on_board1_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '1'
				jmp		recursive_end1
			print_number_on_board2_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '2'
				jmp		recursive_end1
			print_number_on_board3_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '3'
				jmp		recursive_end1
			print_number_on_board4_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '4'
				jmp		recursive_end1
			print_number_on_board5_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '5'
				jmp		recursive_end1
			print_number_on_board6_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]
				mov		byte[eax], '6'
				jmp		recursive_end1
			print_number_on_board7_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '7'
				jmp		recursive_end1
			print_number_on_board8_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '8'
				jmp		recursive_end1
			print_bomb_on_board_1:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '*'
				jmp		recursive_end1


	recursive_end1:

	mov		eax, dword[ebp-4]
	mov		dword[xpos], eax
	mov		eax, dword[ebp-8]
	mov		dword[ypos], eax


	mov		esp, ebp
	pop		ebp
	ret

recursive_func2:
	push	ebp
	mov		ebp, esp

	sub		esp, 8
	mov		eax, dword[xpos]
	mov		dword[ebp-4], eax
	mov		eax, dword[ypos]
	mov		dword[ebp-8], eax

	mov 	eax, WIDTH
	mul		dword[ypos]
	add		eax, [xpos]
	lea		eax, [gameboard + eax]


	cmp		byte[eax], '#'
	je		recursive_end2
	cmp		byte[eax], '0'
	je		print_space_on_board_2
	cmp		byte[eax], '1'
	je		print_number_on_board1_2
	cmp		byte[eax], '2'
	je		print_number_on_board2_2
	cmp		byte[eax], '3'
	je		print_number_on_board3_2
	cmp		byte[eax], '4'
	je		print_number_on_board4_2
	cmp		byte[eax], '5'
	je		print_number_on_board5_2
	cmp		byte[eax], '6'
	je		print_number_on_board6_2
	cmp		byte[eax], '7'
	je		print_number_on_board7_2
	cmp		byte[eax], '8'
	je		print_number_on_board8_2
	cmp		byte[eax], '*'
	je		print_bomb_on_board_2
	jmp		recursive_end2

			print_space_on_board_2:
				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], ' '

			;bottom
				inc		dword[ypos]
				call	recursive_func2
				dec 	dword[ypos]
			;bottomleft
				dec		dword[xpos]
				inc		dword[ypos]
				call	recursive_func2
				inc		dword[xpos]
				dec		dword[ypos]
			;left
				dec		dword[xpos]
				call	recursive_func2
				inc		dword[xpos]
				jmp		recursive_end2
			print_number_on_board1_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '1'
				jmp		recursive_end2
			print_number_on_board2_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '2'
				jmp		recursive_end2
			print_number_on_board3_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '3'
				jmp		recursive_end2
			print_number_on_board4_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '4'
				jmp		recursive_end2
			print_number_on_board5_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '5'
				jmp		recursive_end2
			print_number_on_board6_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]
				mov		byte[eax], '6'
				jmp		recursive_end2
			print_number_on_board7_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '7'
				jmp		recursive_end2
			print_number_on_board8_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '8'
				jmp		recursive_end2
			print_bomb_on_board_2:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '*'
				jmp		recursive_end2


	recursive_end2:

	mov		eax, dword[ebp-4]
	mov		dword[xpos], eax
	mov		eax, dword[ebp-8]
	mov		dword[ypos], eax

	mov		esp, ebp
	pop		ebp
	ret

recursive_func3:
	push	ebp
	mov		ebp, esp

	sub		esp, 8
	mov		eax, dword[xpos]
	mov		dword[ebp-4], eax
	mov		eax, dword[ypos]
	mov		dword[ebp-8], eax

	mov 	eax, WIDTH
	mul		dword[ypos]
	add		eax, [xpos]
	lea		eax, [gameboard + eax]


	cmp		byte[eax], '#'
	je		recursive_end3
	cmp		byte[eax], '0'
	je		print_space_on_board_3
	cmp		byte[eax], '1'
	je		print_number_on_board1_3
	cmp		byte[eax], '2'
	je		print_number_on_board2_3
	cmp		byte[eax], '3'
	je		print_number_on_board3_3
	cmp		byte[eax], '4'
	je		print_number_on_board4_3
	cmp		byte[eax], '5'
	je		print_number_on_board5_3
	cmp		byte[eax], '6'
	je		print_number_on_board6_3
	cmp		byte[eax], '7'
	je		print_number_on_board7_3
	cmp		byte[eax], '8'
	je		print_number_on_board8_3
	cmp		byte[eax], '*'
	je		print_bomb_on_board_3
	jmp		recursive_end3

			print_space_on_board_3:
				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], ' '

			;topleft
				dec		dword[xpos]
				dec		dword[ypos]
				call	recursive_func3
				inc		dword[xpos]
				inc		dword[ypos]
			;top
				dec		dword[ypos]
				call	recursive_func3
				inc		dword[ypos]
			;topright
				inc		dword[xpos]
				dec		dword[ypos]
				call	recursive_func3
				dec		dword[xpos]
				inc		dword[ypos]
				jmp		recursive_end3
			print_number_on_board1_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '1'
				jmp		recursive_end3
			print_number_on_board2_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '2'
				jmp		recursive_end3
			print_number_on_board3_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '3'
				jmp		recursive_end3
			print_number_on_board4_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '4'
				jmp		recursive_end3
			print_number_on_board5_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '5'
				jmp		recursive_end3
			print_number_on_board6_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]
				mov		byte[eax], '6'
				jmp		recursive_end3
			print_number_on_board7_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '7'
				jmp		recursive_end3
			print_number_on_board8_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '8'
				jmp		recursive_end3
			print_bomb_on_board_3:

				mov 	eax, WIDTH
				mul		dword[ypos]
				add		eax, [xpos]
				lea		eax, [board + eax]

				mov		byte[eax], '*'
				jmp		recursive_end3


	recursive_end3:

	mov		eax, dword[ebp-4]
	mov		dword[xpos], eax
	mov		eax, dword[ebp-8]
	mov		dword[ypos], eax

	mov		esp, ebp
	pop		ebp
	ret
