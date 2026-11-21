section .data
	msg db "[ASM] INICIANDO", 10
	msg_len equ $ - msg
	comp db ".Xauthority", 0
	comp_len equ $ - comp
	ruta db "/home/Dio5770", 0

	xa db "'.Xauthority' encontrado", 10
	xa_len equ $ - xa

	si_co db "Conecto correctamente", 10
	si_len equ $ - si_co
	no_exist db "El archivo X11 no existe", 10
	no_exlen equ $ - no_exist
	rechazo db "X11 está rechazando la conección :(", 10
	rechazo_len equ $ - rechazo


	no_co_2 db "La conexíon ha fallado", 10
	no_co_len_2 equ $ - no_co_2
	
section .bss
	g_res resq 1
	buffer resb 4096
	g_x resb 4096
	g_Xau resq 1
	g_2 resq 1
	buffer_2 resq 2
	buffer_resp_x11  resb 512

	fd resd 1
section .data ;// PARA EL SOCKET UNIX
	sockaddr:
		dw 1 ;// AF_UNIX = 1
		db "/tmp/.X11-unix/X0",0 ;// DIRECCION DE SOCKET
		times 108 - ($ - sockaddr - 2) db 0

section .data ;// PARA CREAR LA COMUNICACIÓN CON X11 
	holaaddr:
		db 0X6C ;// VALOR 1
		db 0x00 ;// ESPACIO VACIO NO SE ESCUCHA
		dw 0x000B ; // EN RAM QUEDA ALGO COMO 0X0B, 0X00
		dw 0x0000 ; // 0
		dw 0x0012 ;// BYTES DE  "MIT-MAGIC-COOKIE"
		dw 0x0010 ; // BYTES DE COOKIE SECRETA
		dw 0x0000
		db "MIT-MAGIC-COOKIE-1" ; // TEXTO EN ASCII DEL NOMBRE
		db 0x00,0x00
		cookie_x11:
			times 16 db 0
section .text
	global _start
_start:
	mov rax, 1
	mov rdi, 1
	mov rsi, msg
	mov rdx, msg_len
	syscall
abir:
	mov rax, 2 ; ESTO ES LA SYSCALL DE "OPEN"
	mov rdi, ruta
	mov rsi, 65536
	mov rdx, 0
	syscall
guardar:
	mov [g_res], rax ; GUARDAMOS RAX EN G_RES
leer:
	mov rax, 217 ; ESTO ES LA SYSCALL DE GETDENTS64
	mov rdi, [g_res] ; PONEMOS COMO ARGUMENTO G_RES, QUE GUARDA LO QUE RAX TENIA ANTES
	mov rsi, buffer ; AQUI VA "BUFFER", CONTIENE EL LUGAR DONDE VA A ESCRIBIR
	mov rdx, 4096 ; CUANTO PUEDE ESCRIBIR
	syscall
g_i:
	mov r13, rax
	mov rbx, buffer
	xor rcx,rcx
iterar:
	lea r12, [rbx + 19] ; R12 CONTIENE LA CARPETA ACTUAL
	mov r11, r12 ; PARA LLAMAR A COMPARAR_INI, Y COMPARARLO CON .Xauthority
	call comparar_ini

	cmp r13, r10 ; COMPARA R13 CON R10, SI ESTÁ BIEN ENTONCES VA HACIA OK
	je ok

	movzx r12, word[rbx + 16] ; SI NO SE CUMPLE LO ANTERIOR, RBX APUNTA A LA SIGUIENTE
	add rbx, r12 ; CARPETA

	add rcx,r12 ; INCREMENTA RCX R12
	cmp rcx, rax ; rcx con EL TAMAÑO DE LO QUE LEYÓ SYS_217
	jne iterar ; HACE EL BUCLE
	jmp exit
ok:
	mov [g_Xau], rbx
	; IMPRIMIR MENSAJE
	mov rax, 1
	mov rdi, 1
	mov rsi, xa
	mov rdx, xa_len
	syscall
; ME HACE FALTA LO DE LEER LA LLAVE, LO DEJO PARA DESPUES
cerrar_prep:
	mov r12, [g_res]
cerrar:
	mov rax, 3
	mov rdi, r12
	syscall
;ABRIR EL DE G_XAU , CONTIENE A RBX
abrir_2:
	mov rax, 2
	mov rdi, g_Xau
	mov rsi, 65536 ; // ESTO LO DEJA SOLO PARA LEER
	mov rdx, 0
	syscall
g_abrir_2:
	mov [g_2], rax ;// GUARDAMOS RAX EN LA RAM PARA PODER USAR DESPUES EL VALOR DE RAX
leer_clave:
	mov rax, 217 ;// syscall numero 217, para leer lo que guarde de rax en la ram
	mov rdi, [g_2] ;// carga lo que tenia rax en la syscall 2 para abrir ".Xauthority" y leer su interior
	mov rsi, buffer_2 ;// EL BUFFER DONDE SE VA A ESCRIBIR LA MAGIC-COOKIE-1
	mov rdx, 16 ;// CUANTOS BYTES PUEDE ESCRIBIR
	syscall ;// SYSCALL
	mov r8, buffer_2 ;// R8 GUARDA LA CLAVE 
cerrar_2:
	mov rax, 3 ;// SYSCALL PARA CERRAR
	mov rdi, [g_2] ;// CERRAR .Xauthority
	syscall


abrir_socket:
	mov rax, 41 ;// SYS_SOCKET
	mov rdi, 1 ;// AF_UNIX
	mov rsi, 1 ;// SOCK_STREAM
	mov rdx, 0 ;// PROTOCOLO POR DEFECTO
	syscall
	mov [fd], rax
conectar_socket:
	mov rax, 42 ;// SYS_CONNECT
	mov rdi, [fd]
	mov rsi, sockaddr
	mov rdx, 110
	syscall

	cmp rax, 0 ;// ESTO VERIFICA QUE SE HAYA CONECTADO CORRECTAMENTE
	mov rsi, si_co
	mov rdx, si_len
call print
	je exit
	cmp rax, -2 ;// ESTO VERIFICA SI EL ARCHIVO X11 NO SIRVE
	mov rsi, no_exist
	mov rdx, no_exlen
call print
	je exit
	cmp rax,-111 ;// ESTE VIRIFICA SI X11 RECHAZA LA CONECCIÓN
	mov rsi, rechazo
	mov rdx, rechazo_len
call print
;// QUE HACE FALTA?, PUES HACE FALTA DAR EL HOLA A X11, LUEGO PEDIRLE QUE HAGA ALGO COMO DIBUJAR PANTALLA
cp_clave_x11:
	mov rax, [r8]
	mov [holaaddr + 32], rax
	mov rax, [r8 + 8]
	mov [holaaddr + 40], rax
hablar_x11:
	mov rax, 1 ;// SYS_WRITE
	mov rdi, [fd] ;// FILE DESCRIPTOR QUE DEVUELVE SYS_SOCKET
	mov rsi, holaaddr ;// PUNTERO A HOLAADDR
	mov rdx, 48 ;// TAMAÑO TOTAL
	syscall
leer_x11_respuesta:
	mov rax, 0 ;// SYS_READ
	mov edi, [fd] ;// CONEXIÓN DE SOCKET
	mov rsi, buffer_resp_x11 ; // DONDE ESCRIBE
	mov rdx, 512 ;// ESPACIO ASIGNADO PARA ESCRIBIR
	syscall
cmp_respuesta_x11:
	mov al, [buffer_resp_x11]
	cmp al, 0 ;// SI LA SYS_READ DEVUELVE 0, LA CONEXIÓN FALLA
	jne revisar_uno ;// SI NO DEVOLVIÓ 0, ENTONCES VA A COMPARAR CON 1
	mov rsi, no_co_2 ;// PONE "NO CONECTO" EN RSI PARA LLAMAR A PRINT
	mov rdx, no_co_len_2
	call print
je exit
revisar_uno:
	cmp al, 1 ;// COMPARA EL RESULTADO DE SYS_READ CON 1, SI ES 1 ENTONCES IMPRIME QUE SI CONECTÓ BIEN
	mov rsi, si_co
	mov rdx, si_len
	call print
	syscall
exit:
	mov rax, 60
	mov rdi, 0
	syscall




; // FUNCIONES
comparar_ini:
	mov r9, comp ; R9 AHORA CONTIENE ".Xauthority"
	xor r13,r13 ; DEJAMOS EN 0 R13 PARA PODER USARLO COMO BUCLE
	mov r10, comp_len ; CONTIENE EL TAMAÑO EN BYTES DE ".Xauthority"
comparar:
	mov dl, byte[r9 + r13] ; CONTIENE UN SOLO BYTE
	mov sil, byte[r11 + r13] ; CONTIENE UN SOLO BYTE
	cmp dl,sil ; COMPARA BL CON AL, SI ES IGUAL ENTONCES SIGUE, SI NO ENTONCES TE SACA
	jne no ; IF(CHAR DL != CHAR SIL){RETURN 1}

	inc r13
	cmp r13, r10
	jne comparar
	je sal
no:
	ret
sal:
	ret
print:
	mov rax, 1
	mov rdi, 1
	syscall
	ret

