# T0 - Programa de teste sem hazards
# ISA MIPS32 reduzida

# Inicialização dos registradores
addi $1,  $0, 10
addi $2,  $0, 20
addi $3,  $0, 30
addi $4,  $0, 40
addi $5,  $0, 50
addi $6,  $0, 60
addi $7,  $0, 70
addi $8,  $0, 80
addi $9,  $0, 90
addi $10, $0, 100
addi $11, $0, 1
addi $12, $0, 2

# Operações aritméticas e lógicas
add $13, $1, $2
sub $14, $4, $3
and $15, $5, $6
or  $16, $7, $8
slt $17, $9, $10
slt $18, $10, $9

# Escrita na memória
sw $1, 0($0)
sw $2, 4($0)
sw $3, 8($0)

# Leitura da memória
lw $19, 0($0)
lw $20, 4($0)
lw $21, 8($0)

# Desvio condicional não tomado
beq $11, $12, 5

# Continuação das operações
addi $22, $13, 5
add $23, $14, $15
sub $24, $16, $13
and $25, $19, $20
or $26, $19, $20
add $27, $21, $22
sub $28, $23, $24
slt $29, $18, $17

break
