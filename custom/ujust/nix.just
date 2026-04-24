# vim: set ft=make :
############
# nix.just
############

# Show Nix installation status
[group('Nix')]
nix-status:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Nix Installation Status ==="
    if [[ -f /var/nix/.nix-installed ]]; then
        echo "Status: Instalado ✓"
        if command -v nix &>/dev/null; then
            echo "Versão: $(nix --version 2>/dev/null || echo 'desconhecida')"
        fi
        if systemctl is-active --quiet nix-daemon.service 2>/dev/null; then
            echo "Daemon: ativo ✓"
        else
            echo "Daemon: inativo"
        fi
    elif systemctl is-active --quiet nix-first-boot.service 2>/dev/null; then
        echo "Status: Instalando... (acompanhe os logs com: journalctl -u nix-first-boot.service -f)"
    elif systemctl is-failed --quiet nix-first-boot.service 2>/dev/null; then
        echo "Status: Falha na instalação"
        echo "Execute 'ujust nix-install' para tentar novamente, ou veja os logs:"
        echo "  journalctl -u nix-first-boot.service"
    else
        echo "Status: Não instalado"
        echo "Execute 'ujust nix-install' para instalar o Nix"
    fi

# Install Nix via DeterminateSystems nix-installer (triggers the first-boot service)
[group('Nix')]
nix-install:
    #!/usr/bin/bash
    set -euo pipefail
    if [[ -f /var/nix/.nix-installed ]]; then
        echo "Nix já está instalado."
        if command -v nix &>/dev/null; then
            echo "Versão: $(nix --version)"
        fi
        exit 0
    fi
    echo "Iniciando instalação do Nix..."
    echo "Esta operação requer conexão com a internet para baixar os pacotes Nix."
    echo ""
    # Reset a failed first-boot service so it can be started again
    sudo systemctl reset-failed nix-first-boot.service 2>/dev/null || true
    # Ensure /var/nix exists and nix.mount is active before running the installer
    sudo systemctl start nix.mount
    # Start (or restart) the first-boot installation service
    sudo systemctl start nix-first-boot.service &
    # Follow the installation logs in real time
    sudo journalctl -u nix-first-boot.service -f --no-tail
    # Verify the result
    if [[ -f /var/nix/.nix-installed ]]; then
        echo ""
        echo "Nix instalado com sucesso!"
        echo "Faça logout e login novamente para usar o Nix, ou execute:"
        echo "  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    else
        echo ""
        echo "A instalação do Nix pode ter falhado. Veja os logs:"
        echo "  journalctl -u nix-first-boot.service"
        exit 1
    fi

# Uninstall Nix using the DeterminateSystems uninstaller
[group('Nix')]
nix-uninstall:
    #!/usr/bin/bash
    set -euo pipefail
    if [[ ! -f /var/nix/.nix-installed ]]; then
        echo "Nix não está instalado."
        exit 0
    fi
    if ! gum confirm "Deseja desinstalar o Nix? Esta ação removerá todos os pacotes instalados via Nix."; then
        echo "Operação cancelada."
        exit 0
    fi
    echo "Desinstalando Nix..."
    sudo /usr/libexec/nix-installer uninstall --no-confirm
    sudo rm -f /var/nix/.nix-installed
    echo "Nix desinstalado."
    echo "Nota: /var/nix pode ainda conter arquivos residuais."
    echo "Para remover completamente, execute: sudo rm -rf /var/nix"
