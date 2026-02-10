.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\gdi32.lib

WinMain PROTO :DWORD, :DWORD, :DWORD, :DWORD
WndProc  PROTO :DWORD, :DWORD, :DWORD, :DWORD

.const
WINDOW_CLASS db "OpcodeArenaWnd", 0
WINDOW_TITLE db "Opcode Arena", 0

ARENA_LEFT   equ 50
ARENA_TOP    equ 50
ARENA_RIGHT  equ 750
ARENA_BOTTOM equ 550

PLAYER_SIZE equ 20
PLAYER_SPEED equ 6

MAX_HP equ 100
ATTACK_DAMAGE equ 10
HITBOX_SIZE equ PLAYER_SIZE + 3

.data
playerX  dd 100
playerY  dd 100
player2X dd 600
player2Y dd 400

; Player 1 keys
keyW db 0
keyA db 0
keyS db 0
keyD db 0

; Player 2 keys
keyUp    db 0
keyDown  db 0
keyLeft  db 0
keyRight db 0

; Health
playerHP dd MAX_HP
player2HP dd MAX_HP

; Attack flags
p1Attack db 0
p2Attack db 0

gameOver db 0
winner db 0 ; 1 = Player 1, 2 = Player 2

p1WinText db "PLAYER 1 WINS - Press R to Restart", 0
p2WinText db "PLAYER 2 WINS - Press R to Restart", 0

.code
start:
    invoke GetModuleHandle, NULL
    invoke WinMain, eax, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax

WinMain PROC hInst:DWORD, hPrev:DWORD, lpCmd:DWORD, nShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hwnd:DWORD

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0

    mov eax, hInst
    mov wc.hInstance, eax
    mov wc.hbrBackground, NULL

    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET WINDOW_CLASS

    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax

    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, ADDR wc

    invoke CreateWindowEx, 0,
        ADDR WINDOW_CLASS,
        ADDR WINDOW_TITLE,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        800, 600,
        NULL, NULL,
        hInst, NULL

    mov hwnd, eax
    invoke ShowWindow, hwnd, SW_SHOWNORMAL
    invoke UpdateWindow, hwnd
    invoke SetForegroundWindow, hwnd
    invoke SetFocus, hwnd

    ; Start game timer (~60 FPS)
    invoke SetTimer, hwnd, 1, 16, NULL

msg_loop:
    invoke GetMessage, ADDR msg, NULL, 0, 0
    cmp eax, 0
    je exit_loop
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp msg_loop

exit_loop:
    mov eax, msg.wParam
    ret
WinMain ENDP

WndProc PROC hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL ps:PAINTSTRUCT
    LOCAL rc:RECT
    LOCAL hdc:DWORD
    LOCAL hBrush:DWORD
    LOCAL hPen:DWORD
    LOCAL hOldPen:DWORD

    ; double buffering locals
    LOCAL memDC:DWORD
    LOCAL hBmp:DWORD
    LOCAL hOldBmp:DWORD

    .if uMsg == WM_ERASEBKGND
        mov eax, 1
        ret

    .elseif uMsg == WM_GETDLGCODE
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        or eax, DLGC_WANTARROWS
        ret

    ; Input state update
    .elseif uMsg == WM_KEYDOWN
        mov eax, wParam
        
        cmp gameOver, 1
        je only_restart_allowed
        jmp handle_keys

        only_restart_allowed:
            cmp eax, 'R'
            jne keydown_done
        
        ; Restart game
        mov playerHP, MAX_HP
        mov player2HP, MAX_HP
        mov playerX, 100
        mov playerY, 100
        mov player2X, 600
        mov player2Y, 400
        mov gameOver, 0
        mov winner, 0
        jmp keydown_done
        
handle_keys:
        
        .if eax == 'W'
            mov keyW, 1
        .elseif eax == 'A'
            mov keyA, 1
        .elseif eax == 'S'
            mov keyS, 1
        .elseif eax == 'D'
            mov keyD, 1
        .elseif eax == VK_UP
            mov keyUp, 1
        .elseif eax == VK_DOWN
            mov keyDown, 1
        .elseif eax == VK_LEFT
            mov keyLeft, 1
        .elseif eax == VK_RIGHT
            mov keyRight, 1
        .elseif eax == VK_SPACE
            cmp p1Attack, 0
            jne skip_p1_attack
            mov p1Attack, 1
    skip_p1_attack:
        .elseif eax == VK_RETURN
            cmp p2Attack, 0
            jne skip_p2_attack
            mov p2Attack, 1
    skip_p2_attack:
            .endif
        
keydown_done:
        xor eax, eax
        ret

    .elseif uMsg == WM_SYSKEYDOWN
        mov eax, wParam
        jmp handle_keys
    
    .elseif uMsg == WM_SYSKEYUP
        mov eax, wParam
        jmp keyup_handler

    .elseif uMsg == WM_KEYUP
        mov eax, wParam

keyup_handler:

        .if eax == 'W'
            mov keyW, 0
        .elseif eax == 'A'
            mov keyA, 0
        .elseif eax == 'S'
            mov keyS, 0
        .elseif eax == 'D'
            mov keyD, 0
        .elseif eax == VK_UP
            mov keyUp, 0
        .elseif eax == VK_DOWN
            mov keyDown, 0
        .elseif eax == VK_LEFT
            mov keyLeft, 0
        .elseif eax == VK_RIGHT
            mov keyRight, 0
        .endif

        xor eax, eax
        ret

    ; Game update loop
        .elseif uMsg == WM_TIMER

        cmp gameOver, 1
        je timer_render_only
        
        ; Player 1 movement
        cmp keyW, 1
        jne p1_no_w
        sub playerY, PLAYER_SPEED
p1_no_w:

        cmp keyS, 1
        jne p1_no_s
        add playerY, PLAYER_SPEED
p1_no_s:

        cmp keyA, 1
        jne p1_no_a
        sub playerX, PLAYER_SPEED
p1_no_a:

        cmp keyD, 1
        jne p1_no_d
        add playerX, PLAYER_SPEED
p1_no_d:

        ; Player 2 movement
        cmp byte ptr keyUp, 1
        jne p2_no_up
        sub player2Y, PLAYER_SPEED
p2_no_up:

        cmp byte ptr keyDown, 1
        jne p2_no_down
        add player2Y, PLAYER_SPEED
p2_no_down:

        cmp byte ptr keyLeft, 1
        jne p2_no_left
        sub player2X, PLAYER_SPEED
p2_no_left:

        cmp byte ptr keyRight, 1
        jne p2_no_right
        add player2X, PLAYER_SPEED
p2_no_right:

        ; Clamp Player 1X
        mov eax, playerX
        cmp eax, ARENA_LEFT
        jge p1_x_right_ok
        mov playerX, ARENA_LEFT

p1_x_right_ok:
        mov eax, playerX
        cmp eax, ARENA_RIGHT - PLAYER_SIZE
        jle p1_y_clamp
        mov playerX, ARENA_RIGHT - PLAYER_SIZE

        ; Clamp Player 1Y
p1_y_clamp:
        mov eax, playerY
        cmp eax, ARENA_TOP
        jge p1_y_bottom_ok
        mov playerY, ARENA_TOP

p1_y_bottom_ok:
        mov eax, playerY
        cmp eax, ARENA_BOTTOM - PLAYER_SIZE
        jle p2_x_clamp
        mov playerY, ARENA_BOTTOM - PLAYER_SIZE

        ; Clamp Player 2X
p2_x_clamp:
        mov eax, player2X
        cmp eax, ARENA_LEFT
        jge p2_x_right_ok
        mov player2X, ARENA_LEFT

p2_x_right_ok:
        mov eax, player2X
        cmp eax, ARENA_RIGHT - PLAYER_SIZE
        jle p2_y_clamp
        mov player2X, ARENA_RIGHT - PLAYER_SIZE

        ; Clamp Player 2Y
p2_y_clamp:
        mov eax, player2Y
        cmp eax, ARENA_TOP
        jge p2_y_bottom_check
        mov player2Y, ARENA_TOP

p2_y_bottom_check:
        mov eax, player2Y
        cmp eax, ARENA_BOTTOM - PLAYER_SIZE
        jle p2_y_done
        mov player2Y, ARENA_BOTTOM - PLAYER_SIZE

p2_y_done:

        ; Combat mechanics

        ; Player 1 attack
        cmp p1Attack, 1
        jne p1_no_attack

        ; A.right > B.left
        mov eax, playerX
        add eax, HITBOX_SIZE
        cmp eax, player2X
        jle p1_no_attack

        ; A.left < B.right
        mov eax, playerX
        mov ebx, player2X
        add ebx, HITBOX_SIZE
        cmp eax, ebx
        jge p1_no_attack

        ; A.bottom > B.top
        mov eax, playerY
        add eax, HITBOX_SIZE
        cmp eax, player2Y
        jle p1_no_attack

        ; A.top < B.bottom
        mov eax, playerY
        mov ebx, player2Y
        add ebx, HITBOX_SIZE
        cmp eax, ebx
        jge p1_no_attack

        ; Apply damage
        sub player2HP, ATTACK_DAMAGE
        cmp player2HP, 0
        jge p1_attack_done
        mov player2HP, 0
        p1_attack_done:
        mov p1Attack, 0

p1_no_attack:

        ; Player 2 attack
        cmp p2Attack, 1
        jne p2_no_attack

        mov eax, player2X
        add eax, HITBOX_SIZE
        cmp eax, playerX
        jle p2_no_attack

        mov eax, player2X
        mov ebx, playerX
        add ebx, HITBOX_SIZE
        cmp eax, ebx
        jge p2_no_attack

        mov eax, player2Y
        add eax, HITBOX_SIZE
        cmp eax, playerY
        jle p2_no_attack

        mov eax, player2Y
        mov ebx, playerY
        add ebx, HITBOX_SIZE
        cmp eax, ebx
        jge p2_no_attack

        sub playerHP, ATTACK_DAMAGE
        cmp playerHP, 0
        jge p2_attack_done
        mov playerHP, 0
        p2_attack_done:
        mov p2Attack, 0

p2_no_attack:

        ; Clamp health
        cmp playerHP, 0
        jge hp1_ok
        mov playerHP, 0
hp1_ok:
        
        cmp playerHP, MAX_HP
        jle hp1_max_ok
        mov playerHP, MAX_HP
hp1_max_ok:

        cmp player2HP, 0
        jge hp2_ok
        mov player2HP, 0
hp2_ok:

        cmp player2HP, MAX_HP
        jle hp2_max_ok
        mov player2HP, MAX_HP
hp2_max_ok:

        cmp playerHP, 0
        jg p1_alive
        mov gameOver, 1
        mov winner, 2
        invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW
        jmp timer_render_only
p1_alive:

        cmp player2HP, 0
        jg timer_render_only
        mov gameOver, 1
        mov winner, 1
        invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW

timer_render_only:

        invoke InvalidateRect, hWnd, NULL, FALSE
        xor eax, eax
        ret
        
    ; Rendering
        .elseif uMsg == WM_PAINT
            invoke BeginPaint, hWnd, ADDR ps
            mov hdc, eax

            ; Get client size
            invoke GetClientRect, hWnd, ADDR rc

            ; Create memory DC
            invoke CreateCompatibleDC, hdc
            mov memDC, eax

            ; Create back buffer bitmap
            invoke CreateCompatibleBitmap, hdc, rc.right, rc.bottom
            mov hBmp, eax

            invoke SelectObject, memDC, hBmp
            mov hOldBmp, eax

            ; Draw everything to memDC

            ; Background
            invoke CreateSolidBrush, 0202020h
            mov hBrush, eax
            invoke FillRect, memDC, ADDR rc, hBrush
            invoke DeleteObject, hBrush

            ; Arena
            invoke CreatePen, PS_SOLID, 3, 00FFFFFFh
            mov hPen, eax
            invoke SelectObject, memDC, hPen
            mov hOldPen, eax
            invoke Rectangle, memDC,
                ARENA_LEFT, ARENA_TOP,
                ARENA_RIGHT, ARENA_BOTTOM
            invoke SelectObject, memDC, hOldPen
            invoke DeleteObject, hPen

            ; Player 1
            invoke CreateSolidBrush, 0000FF00h
            mov hBrush, eax
            invoke SelectObject, memDC, hBrush
            mov eax, playerX
            mov ebx, eax
            mov ecx, playerY
            mov edx, ecx
            add eax, PLAYER_SIZE
            add ecx, PLAYER_SIZE
            invoke Rectangle, memDC, ebx, edx, eax, ecx
            invoke DeleteObject, hBrush

            ; Player 1 Health Bar
            invoke CreateSolidBrush, 0000FF00h
            mov hBrush, eax
            invoke SelectObject, memDC, hBrush

            mov eax, playerHP
            imul eax, PLAYER_SIZE
            mov ecx, MAX_HP
            cdq
            idiv ecx ; eax = scaled bar width

            ; left
            mov ebx, playerX

            ; top
            mov ecx, playerY
            sub ecx, 8

            ; right
            mov edx, ebx
            add edx, eax

            ; bottom
            mov esi, ecx
            add esi, 5

            invoke Rectangle, memDC,
                ebx,
                ecx,
                edx,
                esi

            invoke DeleteObject, hBrush

            ; Player 2
            invoke CreateSolidBrush, 00FF0000h
            mov hBrush, eax
            invoke SelectObject, memDC, hBrush
            mov eax, player2X
            mov ebx, eax
            mov ecx, player2Y
            mov edx, ecx
            add eax, PLAYER_SIZE
            add ecx, PLAYER_SIZE
            invoke Rectangle, memDC, ebx, edx, eax, ecx
            invoke DeleteObject, hBrush

            ; Player 2 Health Bar
            invoke CreateSolidBrush, 000000FFh
            mov hBrush, eax
            invoke SelectObject, memDC, hBrush

            mov eax, player2HP
            imul eax, PLAYER_SIZE
            mov ecx, MAX_HP
            cdq
            idiv ecx 

            ; left
            mov ebx, player2X

            ; top
            mov ecx, player2Y
            sub ecx, 8

            ; right
            mov edx, ebx
            add edx, eax

            ; bottom
            mov esi, ecx
            add esi, 5

            invoke Rectangle, memDC,
                ebx,
                ecx,
                edx,
                esi

            invoke DeleteObject, hBrush

            cmp gameOver, 1
            jne skip_win_text

            invoke SetBkMode, memDC, TRANSPARENT
            invoke SetTextColor, memDC, 00FFFFFFh

            cmp winner, 1
            jne p2wins_draw
            invoke TextOut, memDC, 200, 20, ADDR p1WinText, 31
            jmp skip_win_text

            p2wins_draw:
            invoke TextOut, memDC, 200, 20, ADDR p2WinText, 31

            skip_win_text:

            ; Blit Final Frame
            invoke BitBlt, hdc,
                0, 0,
                rc.right, rc.bottom,
                memDC,
                0, 0,
                SRCCOPY
            
    paint_done:
            
            ; Cleanup
            invoke SelectObject, memDC, hOldBmp
            invoke DeleteObject, hBmp
            invoke DeleteDC, memDC

            invoke EndPaint, hWnd, ADDR ps
            xor eax, eax
            ret

    .elseif uMsg == WM_DESTROY
        invoke KillTimer, hWnd, 1
        invoke PostQuitMessage, 0
        xor eax, eax
        ret
    .endif

    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret
WndProc ENDP

END start