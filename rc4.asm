; https://github.com/dimeritium-foil/rc4-asm
; author: farris essam

#make_bin#

; set loading address, .bin file will be loaded to this address:
#LOAD_SEGMENT=0500h#
#LOAD_OFFSET=0000h#

; set entry point:
#CS=0500h#	; same as loading segment
#IP=0000h#

; set segment registers
#DS=1500h#
#ES=1500h#

; set stack
#SS=3500h#
#SP=FFFEh#	; set to top of the stack

; set general registers 
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

include emu8086.inc

; all the data is in the ES, with offsets:
; 0000: state array
; 0100: key
; 0200: keystream
; 0300: keylength
; 0400: keystreamlength

of_s     equ 0000h
of_k     equ 0100h
of_ks    equ 0200h
of_klen  equ 0300h
of_kslen equ 0400h

;first we get the key and keystream length from the user

mov dx, 0ffh ; max buffer size
mov di, of_k ; location to store input string

print "Enter key: "
call get_string

; newline
print 10
print 13

print "Enter keystream length: "
call scan_num

; newline
print 10
print 13

; store keystream length
mov byte ptr es:[of_kslen], cl

; now we're gonna calculate the length of the entered key and store it
mov ax, 0
mov di, of_k

keylength:
    inc ah
    scasb
    loopnz keylength

dec ah ; bec the loop is done one extra time
mov byte ptr es:[of_klen], ah 
                 
; initialize the state array S at the start of the ES
; from 0 to 254 inside the loop, then add the remaining 255 after the loop
mov cl, 255
mov di, of_s

movestate:    
    mov al, 255
    sub al, cl
    stosb
    loop movestate

mov al, 255
stosb   

; 1. key-scheduling algorithm (ksa)
; now we're gonna scramble the state array using the key
; we'll use bp as the i pointer, and bx as the j pointer
; note: a % b == a & (b - 1) if b is a power of 2

mov cx, 256
mov bx, 0

ksa:
    mov bp, 256
    sub bp, cx ; i
    add bl, byte ptr es:[of_s + bp] ; adding S[i] to j
    
    mov ax, bp
    
    div byte ptr es:[of_klen] ; ah = i % keylen
    mov dh, 0
    mov dl, ah
    mov si, dx
    add bl, byte ptr es:[of_k + si] ; adding key[i % keylen]
    
    and bl, 255 ; mod 256        

    ; swap S[i] and S[j]
    mov al, byte ptr es:[of_s + bp]
    xchg al, byte ptr es:[of_s + bx]
    xchg al, byte ptr es:[of_s + bp]
    
    loop ksa

; 2. pseudo-random generation algorithm (prga)
; now we're gonna generate the keystream
; again we'll use bp as the i pointer, and bx as the j pointer
; and we'll use the keystream lenght as the counter

mov ch, 0
mov cl, byte ptr es:[of_kslen]

mov bx, 0
mov ax, 0
mov di, of_ks

prga:
    mov bp, es:[of_kslen]
    sub bp, cx
    
    inc bp
    and bp, 255 ; mod 256
    
    add bl, byte ptr es:[of_s + bp] ; adding S[i] to j
    and bp, 255 ; mod 256
    
    ; swap S[i] and S[j]
    mov al, byte ptr es:[of_s + bp]
    xchg al, byte ptr es:[of_s + bx]
    xchg al, byte ptr es:[of_s + bp]
    
    ; S[i] + S[j]
    mov al, byte ptr es:[of_s + bp]
    add al, byte ptr es:[of_s + bx]
    
    and al, 255 ; mod 256
    
    ; then using it to index S
    mov si, ax
    mov al, byte ptr es:[of_s + si]
    
    stosb
    
    loop prga

; finally we're gonna print out the keystream
; in both decimal and hexadecimal

print 10 ; empty line

printn "keystream"
printn "========="
print "dec: "

mov cx, es:[of_kslen]
mov ax, 0
mov bx, 0

printks_dec:
    mov bl, es:[of_kslen]
    sub bx, cx
    
    mov al, byte ptr es:[of_ks + bx]
    call print_num_uns
    print 32 ;space
    
    loop printks_dec

; two newlines
print 10
print 10
print 13

print "hex: "

mov cx, es:[of_kslen]
mov ax, 0
mov bx, 0

printks_hex:
    mov bl, es:[of_kslen]
    sub bx, cx
    
    mov ah, byte ptr es:[of_ks + bx]    
    
    call asciihex
    
    mov cs:[msn], ah
    mov cs:[lsn], al
    
    ; print most significant nibble
    call pthis
    msn db ?, 0
    
    ; print least significant nibble
    call pthis
    lsn db ?, 0
    
    print 32 ;space
    
    loop printks_hex
 
hlt

asciihex:
    ; function converts a number in ah to it's ascii equivelant hex and stores in ah and al
    mov al, ah

    ; most significant nibble
    and ah, 0f0h
    shr ah, 4 
    
    ; least significant nibble
    and al, 00fh
    
    ; convert msn
    mov dl, ah
    call dec2hex
    mov ah, dl
    
    ; convert lsn
    mov dl, al
    call dec2hex
    mov al, dl

    dec2hex:
        ; jump to hexchar if dl >= 10
        cmp dl, 10
        jae hexchar
        jmp decchar
        
        hexchar:
            add dl, 87
            ret
           
        decchar:
            add dl, 48
            ret
            
; for the functions and macros from emu8086.inc to work
define_get_string
define_scan_num
define_print_num_uns
define_pthis
end
