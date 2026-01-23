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

PLAYER_SIZE  equ 20
PLAYER_SPEED equ 10

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

    .if uMsg == WM_ERASEBKGND
        mov eax, 1
        ret

    ; =========================
    ; INPUT STATE UPDATE
    ; =========================
    .elseif uMsg == WM_KEYDOWN
        mov eax, wParam

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
        .endif

        xor eax, eax
        ret

    .elseif uMsg == WM_KEYUP
        mov eax, wParam

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

    ; =========================
    ; GAME UPDATE LOOP
    ; =========================
    .elseif uMsg == WM_TIMER

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
        cmp keyUp, 1
        jne p2_no_up
        sub player2Y, PLAYER_SPEED
p2_no_up:

        cmp keyDown, 1
        jne p2_no_down
        add player2Y, PLAYER_SPEED
p2_no_down:

        cmp keyLeft, 1
        jne p2_no_left
        sub player2X, PLAYER_SPEED
p2_no_left:

        cmp keyRight, 1
        jne p2_no_right
        add player2X, PLAYER_SPEED
p2_no_right:

        invoke InvalidateRect, hWnd, NULL, FALSE
        xor eax, eax
        ret

    ; =========================
    ; RENDERING
    ; =========================
    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax

        invoke GetClientRect, hWnd, ADDR rc
        invoke CreateSolidBrush, 0202020h
        mov hBrush, eax
        invoke FillRect, hdc, ADDR rc, hBrush
        invoke DeleteObject, hBrush

        invoke CreatePen, PS_SOLID, 3, 00FFFFFFh
        mov hPen, eax
        invoke SelectObject, hdc, hPen
        mov hOldPen, eax
        invoke Rectangle, hdc,
            ARENA_LEFT, ARENA_TOP,
            ARENA_RIGHT, ARENA_BOTTOM
        invoke SelectObject, hdc, hOldPen
        invoke DeleteObject, hPen

        ; Player 1
        invoke CreateSolidBrush, 0000FF00h
        mov hBrush, eax
        invoke SelectObject, hdc, hBrush
        mov eax, playerX
        mov ebx, eax
        mov ecx, playerY
        mov edx, ecx
        add eax, PLAYER_SIZE
        add ecx, PLAYER_SIZE
        invoke Rectangle, hdc, ebx, edx, eax, ecx
        invoke DeleteObject, hBrush

        ; Player 2
        invoke CreateSolidBrush, 00FF0000h
        mov hBrush, eax
        invoke SelectObject, hdc, hBrush
        mov eax, player2X
        mov ebx, eax
        mov ecx, player2Y
        mov edx, ecx
        add eax, PLAYER_SIZE
        add ecx, PLAYER_SIZE
        invoke Rectangle, hdc, ebx, edx, eax, ecx
        invoke DeleteObject, hBrush

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