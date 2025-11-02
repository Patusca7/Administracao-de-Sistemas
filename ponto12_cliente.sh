#!/bin/bash

# Verifica se o knock está instalado
if ! rpm -q knock > /dev/null; then
    yum install -y epel-release
    yum install -y knock
fi

clear

# Validação do IP
while true; do
    read -p "Insira o IP do servidor: " SERVIDOR
    if [[ "$SERVIDOR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "IP inválido"
    fi
done

# Pergunta o número de portas na sequência
while true; do
    read -p "Quantas portas tem a sequência? " NUM_PORTAS
    if [[ "$NUM_PORTAS" =~ ^[0-9]+$ ]] && [ "$NUM_PORTAS" -gt 0 ]; then
        break
    else
        echo "Número inválido. Por favor insira um número inteiro positivo."
    fi
done

# Recebe as portas e valida
SEQUENCIA=""
for (( i=1; i<=NUM_PORTAS; i++ )); do
    while true; do
        read -p "Insira a porta número $i da sequência: " PORTA
        if [[ "$PORTA" =~ ^[0-9]+$ ]]; then
            SEQUENCIA+="$PORTA "
            break
        else
            echo "Porta inválida. Insira apenas números."
        fi
    done
done

# Remove espaço extra no final
SEQUENCIA=$(echo "$SEQUENCIA" | sed 's/ *$//')

# Envia knock
knock "$SERVIDOR" $SEQUENCIA

# Conecta por SSH
echo "A ligar ao servidor por SSH."
ssh root@"$SERVIDOR"
