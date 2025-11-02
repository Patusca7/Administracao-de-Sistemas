#!/bin/bash

# Função para criar partilha
criar_partilha() {

    # Valida o nome da partilha até que seja válido
    while true; do
        read -p "Insira o caminho para a partilha (ex: /script): " SHARE_PATH
        
        while true; do
            read -p "Insira o IP da rede que pode aceder, sem o /24 : " IP_REDE
            if [[ "$IP_REDE" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                break
            else
                echo " IP inválido"
            fi
        done
        # Adiciona a barra '/' ao início do caminho, se não tiver
            if [[ "$SHARE_PATH" != /* ]]; then
                SHARE_PATH="/$SHARE_PATH"
            fi

        # Verifica se os parâmetros foram fornecidos
        if [ -z "$SHARE_PATH" ] || [ -z "$IP_REDE" ]; then
            echo "Caminho e IP da rede são obrigatórios."
            return
        fi
    break
    done

    # Cria a diretoria da partilha se não existir
    mkdir -p "$SHARE_PATH"
    chmod 777 "$SHARE_PATH"

    # Adiciona a partilha ao arquivo /etc/exports
    echo "$SHARE_PATH    $IP_REDE/24(rw,hide,sync)" >> /etc/exports

    # Reinicia o serviço NFS
    systemctl restart nfs-server
    echo "Partilha criada com sucesso!"
}

# Função para eliminar partilha
eliminar_partilha() {
    # Valida o caminho da partilha até que seja válido
    while true; do
        read -p "Insira o caminho da partilha que pretende eliminar: " PART_NAME

        # Adiciona a barra '/' ao início do caminho, se não tiver
        if [[ "$PART_NAME" != /* ]]; then
            PART_NAME="/$PART_NAME"
        fi

        # Verifica se a partilha existe no arquivo /etc/exports
        if ! grep -q "$PART_NAME" /etc/exports; then
            echo "A partilha '$PART_NAME' não existe. Insira um caminho válido."
        else
            break
        fi
    done

    # Remove a partilha do arquivo /etc/exports
    sed -i "\|$PART_NAME|d" /etc/exports

    # Verifica se a diretoria da partilha existe
    if [ -d "$PART_NAME" ]; then
        # Verifica se a diretoria está vazia
        if [ "$(ls -A "$PART_NAME")" ]; then
            echo "A diretoria '$PART_NAME' não está vazia. Deseja removê-la e todo o seu conteúdo? (s/n)"
            read -p "Escolha: " confirmacao
            if [[ "$confirmacao" =~ ^[Ss]$ ]]; then
                # Remove a diretoria e todos os itens nela
                rm -rf "$PART_NAME"
                echo "Diretoria '$PART_NAME' removida com sucesso."
            else
                echo "Operação cancelada."
            fi
        else
            # Remove a diretoria vazia
            rmdir "$PART_NAME"
            echo "Diretoria '$PART_NAME' removida com sucesso."
        fi
    else
        echo "A diretoria '$PART_NAME' não existe."
    fi

    # Reinicia o serviço NFS
    systemctl restart nfs-server
    echo "Partilha '$PART_NAME' eliminada com sucesso."
}


# Função para alterar partilha
alterar_partilha() {
    # Pede o caminho da partilha para alterar
    while true; do
        read -p "Insira o caminho da partilha que pretende alterar: " OLD_PATH

        # Adiciona a barra '/' ao início do caminho, se não tiver
        if [[ "$OLD_PATH" != /* ]]; then
            OLD_PATH="/$OLD_PATH"
        fi

        # Verifica se a partilha existe no arquivo /etc/exports
        if ! grep -q -E "^$OLD_PATH\s" /etc/exports; then
            echo "A partilha '$OLD_PATH' não existe. Insira um nome válido."
        else
            break
        fi
    done

    # Pede o novo caminho da partilha
    read -p "Insira o novo caminho para a partilha: " NEW_PATH
    if [[ "$NEW_PATH" != /* ]]; then
        NEW_PATH="/$NEW_PATH"
    fi

    # Pede o novo IP
    while true; do
        read -p "Insira o novo IP da rede: " NEW_IP_REDE
        if [[ "$NEW_IP_REDE" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            break
        else
            echo " IP inválido"
        fi
    done

    # Remove a entrada antiga do arquivo /etc/exports
    sed -i "\|^$OLD_PATH\s|d" /etc/exports

    # Adiciona a nova entrada ao arquivo /etc/exports
    echo -e "$NEW_PATH\t$NEW_IP_REDE/24(rw,hide,sync)" >> /etc/exports

    # Move a diretoria antiga para o novo local
    if [ -d "$OLD_PATH" ]; then
        mv "$OLD_PATH" "$NEW_PATH"
        echo "Diretoria movida de '$OLD_PATH' para '$NEW_PATH'."
    fi

    # Reinicia o serviço NFS para aplicar as alterações
    systemctl restart nfs-server

    echo "Partilha alterada com sucesso."
}

# Função para desativar partilha
desativar_partilha() {
    # Valida o caminho da partilha até que seja válido
    while true; do
        read -p "Insira o caminho da partilha que pretende desativar: " PART_NAME

        # Adiciona a barra '/' ao início do caminho, se não tiver
        if [[ "$PART_NAME" != /* ]]; then
            PART_NAME="/$PART_NAME"
        fi

        # Verifica se o nome da partilha não está vazio e se existe no arquivo /etc/exports
        if [[ -z "$PART_NAME" ]]; then
            echo "O nome da partilha não pode estar vazio. Tente novamente."
        elif ! grep -q "$PART_NAME" /etc/exports; then
            echo "A partilha '$PART_NAME' não existe no arquivo /etc/exports. Insira um nome válido."
        else
            break
        fi
    done

    # Desativa a partilha no arquivo de configuração do NFS
    sed -i "s|^$PART_NAME.*|#&|" /etc/exports

    # Reinicia o serviço NFS para aplicar as mudanças
    systemctl restart nfs-server
    echo "Partilha '$PART_NAME' desativada com sucesso."
}

# Função para ativar partilha desativada
ativar_partilha() {
    while true; do
        read -p "Insira o caminho da partilha que pretende ativar: " PART_NAME

        # Adiciona a barra '/' ao início do caminho, se não tiver
        if [[ "$PART_NAME" != /* ]]; then
            PART_NAME="/$PART_NAME"
        fi

        # Verifica se existe uma entrada comentada para a partilha no arquivo
        if grep -q "^#${PART_NAME}" /etc/exports; then
            # Remove o comentário da linha correspondente
            sed -i "s|^#\(${PART_NAME}.*\)|\1|" /etc/exports
            systemctl restart nfs-server
            echo "Partilha '$PART_NAME' ativada com sucesso."
            break
        else
            echo "A partilha '$PART_NAME' não está desativada ou não existe. Tente novamente."
        fi
    done
}

# Função de menu
menu() {
    echo "Menu de Configuração do NFS"
    echo "1) Criar Partilha"
    echo "2) Eliminar Partilha"
    echo "3) Alterar Partilha"
    echo "4) Desativar Partilha"
    echo "5) Ativar Partilha"
    echo "6) Sair"
    read -p "Escolha a opção: " OPCAO

    case $OPCAO in
        1) criar_partilha ;;
        2) eliminar_partilha ;;
        3) alterar_partilha ;;
        4) desativar_partilha ;;
        5) ativar_partilha ;;
        6) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
}

while true; do
    menu
done
