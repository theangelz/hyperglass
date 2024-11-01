#!/usr/bin/env bash

set -e

# Versões mínimas necessárias
MIN_PYTHON_MAJOR="3"
MIN_PYTHON_MINOR="6"
MIN_NODE_MAJOR="20"
MIN_YARN_MAJOR="1"
MIN_REDIS_MAJOR="4"

# Comandos de instalação para diferentes gerenciadores de pacotes
APT_INSTALL="apt-get install -y"
APT_UPDATE="apt update"
YUM_INSTALL="yum install -y"
YUM_UPDATE="yum update"
BREW_INSTALL="brew install"
BREW_UPDATE="brew update"

INSTALL_MAP=(["apt"]="$APT_INSTALL" ["yum"]="$YUM_INSTALL" ["brew"]="$BREW_INSTALL")
UPDATE_MAP=(["apt"]="$APT_UPDATE" ["yum"]="$YUM_UPDATE" ["brew"]="$BREW_UPDATE")

INSTALLER=""
NEEDS_UPDATE="0"
NEEDS_PYTHON="1"
NEEDS_NODE="1"
NEEDS_YARN="1"
NEEDS_REDIS="1"

# Função para verificar se um comando existe
has_cmd() {
    which $1 >/dev/null
    if [[ $? == 0 ]]; then
        echo "0"
    else
        echo "1"
    fi
}

# Função para limpar os arquivos temporários
clean_temp() {
    echo "Cleaning up temporary files..."
    rm -rf /tmp/yarnkey.gpg /tmp/nodesetup.sh /tmp/hyperglass /tmp/build
}

# Função para pegar a versão do Python
python3_version() {
    local ver_digits=($(python3 --version 2>&1 | awk '{print $2}' | tr '.' ' '))
    local major="${ver_digits[0]}"
    local minor="${ver_digits[1]}"

    if [[ $major != $MIN_PYTHON_MAJOR || $minor -lt $MIN_PYTHON_MINOR ]]; then
        echo "1"
    else
        echo "0"
    fi
}

# Função para pegar a versão do Node.js
node_version() {
    local ver_digits=($(node --version | tr -d 'v' | tr '.' ' '))
    local major="${ver_digits[0]}"

    if [[ $major -lt $MIN_NODE_MAJOR ]]; then
        echo "1"
    else
        echo "0"
    fi
}

# Função para detectar o gerenciador de pacotes da plataforma
get_platform() {
    local use_apt=$(has_cmd apt-get)
    local use_yum=$(has_cmd yum)
    local use_brew=$(has_cmd brew)

    if [[ $use_apt == 0 ]]; then
        INSTALLER="apt"
    elif [[ $use_yum == 0 ]]; then
        INSTALLER="yum"
    elif [[ $use_brew == 0 ]]; then
        INSTALLER="brew"
    else
        echo "[ERROR] Unable to identify this system's package manager"
        exit 1
    fi
}

# Função para desinstalar pacotes previamente instalados
uninstall_previous() {
    echo "[INFO] Removing previously installed dependencies..."

    # Remover dependências Python
    pip3 uninstall -y hyperglass poetry

    # Remover Node.js, Yarn e Redis
    if [[ $INSTALLER == "apt" ]]; then
        apt-get purge -y nodejs yarn redis-server
    elif [[ $INSTALLER == "yum" ]]; then
        yum remove -y nodejs yarn redis
    elif [[ $INSTALLER == "brew" ]]; then
        brew uninstall node yarn redis
    fi

    # Limpar diretórios temporários
    clean_temp

    echo "[INFO] Previous dependencies removed successfully."
}

# Instalação do Python, Node.js, Yarn e Redis
install_dependencies() {
    echo "[INFO] Installing dependencies..."

    if [[ $INSTALLER == "apt" ]]; then
        apt-get update
        apt-get install -y python3-dev python3-pip nodejs yarn redis-server
    elif [[ $INSTALLER == "yum" ]]; then
        yum update
        yum install -y python3-devel python3-pip nodejs yarn redis
    elif [[ $INSTALLER == "brew" ]]; then
        brew update
        brew install python3 node yarn redis
    fi

    echo "[INFO] Dependencies installed successfully."
}

# Instalação do hyperglass usando o poetry
install_hyperglass() {
    echo "[INFO] Installing hyperglass..."

    # Instalando o poetry corretamente
    curl -sSL https://install.python-poetry.org | python3 -
    export PATH="/opt/poetry/bin:$PATH"

    [ -d "/tmp/hyperglass" ] && rm -rf /tmp/hyperglass
    git clone https://github.com/thatmattlove/hyperglass --depth=1 /tmp/hyperglass
    cd /tmp/hyperglass

    poetry install  # Usa o poetry para instalar o projeto

    if [[ $? == 0 ]]; then
        source $HOME/.profile
        export LC_ALL=C.UTF-8
        export LANG=C.UTF-8
        echo "[SUCCESS] hyperglass installed successfully."
    else
        echo "[ERROR] An error occurred while trying to install hyperglass."
        exit 1
    fi
}

# Executa a remoção e nova instalação
trap clean_temp SIGINT

while true; do
    if (($EUID != 0)); then
        echo '[ERROR] hyperglass installer must be run with root privileges. Try running with `sudo`'
        exit 1
    fi

    get_platform

    # Remover tudo previamente instalado
    uninstall_previous

    # Instalar todas as dependências novamente
    install_dependencies

    # Instalar o hyperglass usando o poetry
    install_hyperglass

    echo '[SUCCESS] hyperglass installation was successful! You can now run `hyperglass --help` to see available commands.'
    exit 0
done
