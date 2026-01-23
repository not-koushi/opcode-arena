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
playerX dd 100
playerY dd 100
player2X dd 600
player2Y dd 400

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

    ; IMPORTANT: disable automatic background erase
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
        ; Prevent flickering by not erasing background
        mov eax, 1
        ret

    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax

        ; Clear full client area
        invoke GetClientRect, hWnd, ADDR rc

        invoke CreateSolidBrush, 0202020h
        mov hBrush, eax

        invoke FillRect, hdc, ADDR rc, hBrush
        invoke DeleteObject, hBrush

        ; Draw arena
        invoke CreatePen, PS_SOLID, 3, 00FFFFFFh
        mov hPen, eax

        invoke SelectObject, hdc, hPen
        mov hOldPen, eax

        invoke Rectangle, hdc,
            ARENA_LEFT,
            ARENA_TOP,
            ARENA_RIGHT,
            ARENA_BOTTOM

        invoke SelectObject, hdc, hOldPen
        invoke DeleteObject, hPen

        ; Draw player
        invoke CreateSolidBrush, 0000FF00h
        mov hBrush, eax

        invoke SelectObject, hdc, hBrush

        mov eax, playerX
        mov ebx, eax
        mov ecx, playerY
        mov edx, ecx

        add eax, PLAYER_SIZE
        add ecx, PLAYER_SIZE

        invoke Rectangle, hdc,
            ebx,
            edx,
            eax,
            ecx

        invoke DeleteObject, hBrush

        ; Draw Player 2
        invoke CreateSolidBrush, 00FF0000h
        mov hBrush, eax

        invoke SelectObject, hdc, hBrush

        mov eax, player2X
        mov ebx, eax
        mov ecx, player2Y
        mov edx, ecx

        add eax, PLAYER_SIZE
        add ecx, PLAYER_SIZE

        invoke Rectangle, hdc,
            ebx,
            edx,
            eax,
            ecx
        
        invoke DeleteObject, hBrush

        invoke EndPaint, hWnd, ADDR ps
        xor eax, eax
        ret

        .elseif uMsg == WM_KEYDOWN

        ; Ignore auto-repeat keydown
        mov eax, lParam
        test eax, 40000000h
        jnz ignore_key

        mov eax, wParam

        ; Movement (single-step per press)
        .if eax == 'W'
            sub playerY, PLAYER_SPEED
        .elseif eax == 'S'
            add playerY, PLAYER_SPEED
        .elseif eax == 'A'
            sub playerX, PLAYER_SPEED
        .elseif eax == 'D'
            add playerX, PLAYER_SPEED
        .elseif eax == VK_UP
            sub player2Y, PLAYER_SPEED
        .elseif eax == VK_DOWN
            add player2Y, PLAYER_SPEED
        .elseif eax == VK_LEFT
            sub player2X, PLAYER_SPEED
        .elseif eax == VK_RIGHT
            add player2X, PLAYER_SPEED
        .endif

        ; Clamp X
        mov eax, playerX
        cmp eax, ARENA_LEFT
        jge clamp_right
        mov playerX, ARENA_LEFT

clamp_right:
        mov eax, playerX
        cmp eax, ARENA_RIGHT - PLAYER_SIZE
        jle clamp_top
        mov playerX, ARENA_RIGHT - PLAYER_SIZE

        ; Clamp Y
clamp_top:
        mov eax, playerY
        cmp eax, ARENA_TOP
        jge clamp_bottom
        mov playerY, ARENA_TOP

clamp_bottom:
        mov eax, playerY
        cmp eax, ARENA_BOTTOM - PLAYER_SIZE
        jle done_input
        mov playerY, ARENA_BOTTOM - PLAYER_SIZE

revert_move:
    ; no-op for now

; collision check
collision_check:
    mov eax, playerX
    sub eax, player2X
    cmp eax, PLAYER_SIZE
    jl revert_move

done_input:
        invoke InvalidateRect, hWnd, NULL, FALSE
        xor eax, eax
        ret

ignore_key:
        xor eax, eax
        ret


    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage, 0
        xor eax, eax
        ret
    .endif

    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret
WndProc ENDP

END start