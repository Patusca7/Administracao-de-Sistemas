#!/bin/bash

while true; do
    echo "Menu Principal"
    echo "1) Pontos 1, 3, 4, 5, 6, 8"
    echo "2) Ponto 2"
    echo "3) Ponto 7"
    echo "4) Ponto 9"
    echo "5) Ponto 10"
    echo "6) Ponto 11"
    echo "7) Ponto 12"
    echo "0) Sair"
    read -p "Escolha uma opção: " opcao

    case $opcao in
        1) chmod +x ponto1.sh; ./ponto1.sh;;
        2) chmod +x ponto2.sh; ./ponto2.sh;;
        3) chmod +x ponto7.sh; ./ponto7.sh;;
        4) chmod +x ponto9.sh; ./ponto9.sh;;
        5) chmod +x ponto10.sh; ./ponto10.sh;;
        6) chmod +x ponto11.sh; ./ponto11.sh;;
        7) chmod +x ponto12.sh; ./ponto12.sh;;
        0) break;;
        *) echo "Opção inválida.";;
    esac

    echo ""
    read -p "Pressione qualquer tecla para voltar ao menu."
    clear
done
