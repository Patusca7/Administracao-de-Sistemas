#!/bin/bash

CONFIG_FILE="/etc/knockd.conf"
INTERFACE="enp0s3"
IPTABLES_BLOCK_RULE_COMMENT="Bloquear SSH, para testar port knocking"

function ativar_portknocking() {
    # Pergunta o número de portas
    while true; do
        read -p "Quantas portas pretende na sequência de port knocking? " NUM_PORTAS
        if [[ "$NUM_PORTAS" =~ ^[0-9]+$ ]] && [ "$NUM_PORTAS" -gt 0 ]; then
            break
        else
            echo "Número inválido. Por favor insira um número inteiro positivo."
        fi
    done

    # Pede as portas individualmente
    PORTAS=()
    for (( i=1; i<=NUM_PORTAS; i++ )); do
        while true; do
            read -p "Insira a porta número $i da sequência: " PORTA
            if [[ "$PORTA" =~ ^[0-9]+$ ]] && [ "$PORTA" -ge 1 ] && [ "$PORTA" -le 65535 ]; then
                PORTAS+=("$PORTA")
                break
            else
                echo "Porta inválida. Insira um número entre 1 e 65535."
            fi
        done
    done

    # Gera sequência normal e inversa
    SEQUENCIA_OPEN=$(IFS=, ; echo "${PORTAS[*]}")
    SEQUENCIA_CLOSE=$(IFS=, ; echo "${PORTAS[*]}" | awk -F, '{for(i=NF;i>0;i--) printf "%s%s", $i, (i==1?"":",") }')

    # Escreve a configuração no knockd.conf
    echo -e "[options]\n\tUseSyslog\n\tInterface = $INTERFACE\n\n[openSSH]\n\tsequence\t= $SEQUENCIA_OPEN\n\tseq_timeout\t= 15\n\tcommand\t= /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT\n\ttcpflags\t= syn\n\n[closeSSH]\n\tsequence\t= $SEQUENCIA_CLOSE\n\tseq_timeout\t= 15\n\tcommand\t= /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT\n\ttcpflags\t= syn" > "$CONFIG_FILE"

    # Verifica se a regra de bloqueio já existe
    CHECK_RULE=$(iptables -L INPUT --line-numbers -n | grep "$IPTABLES_BLOCK_RULE_COMMENT" | grep DROP | awk '{print $1}')

    if [[ -n "$CHECK_RULE" ]]; then
        echo "O PortKnocking já está ativo com a sequência definida!"
    else
        iptables -I INPUT 2 -p tcp --dport 22 -m comment --comment "$IPTABLES_BLOCK_RULE_COMMENT" -j DROP
        service iptables save

        systemctl restart knockd
        systemctl restart iptables
        echo "O PortKnocking foi ativado com sucesso!"
        echo "Sequência de abertura: $SEQUENCIA_OPEN"
        echo "Sequência de fecho: $SEQUENCIA_CLOSE"
    fi
}


function desativar_portknocking() {

    # Encontra o número da linha
    RULE_NUM=$(iptables -L INPUT --line-numbers -n | grep "$IPTABLES_BLOCK_RULE_COMMENT" | grep DROP | awk '{print $1}')

    if [[ -n "$RULE_NUM" ]]; then
        iptables -D INPUT "$RULE_NUM"
        echo "Regra de bloqueio SSH removida do iptables (linha $RULE_NUM)."

        service iptables save
        systemctl restart knockd
        systemctl restart iptables
        echo "O PortKnocking foi desativado com sucesso."
    else
        echo "O PortKnocking já está desativado!"
    fi

}


menu() {
    echo "Menu Principal"
    echo "1) Ativar Port Knocking"
    echo "2) Desativar Port Knocking"
    echo "3) Sair"
    read -p "Escolha uma opção: " OPCAO

    case $OPCAO in
        1) ativar_portknocking;;
        2) desativar_portknocking;;
        3) exit 0;;
        *) echo "Opção inválida!";;
    esac
}

while true; do
    menu
done