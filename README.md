# batocera-pcsx2x6
pcsx2x6-standalone para batocera.linux v40

pcsx2x6 - instalação COMPLETA (programa + integração ES num pacote só)
=========================================================================

O que é
-------
Fusão dos dois pacotes das pastas vizinhas (pcsx2x6-standalone +
pcsx2x6-es-integration) num squashfs único e num instalador único.
Rodando este aqui, a Batocera fica com o pcsx2x6 instalado E
aparecendo direto na lista da EmulationStation, sem precisar rodar
dois instaladores em sequência nem se preocupar com a ordem/dependência
entre eles.

Use este se quer tudo de uma vez (o caso normal). Use os pacotes
separados (pcsx2x6-standalone/ e pcsx2x6-es-integration/) só se quiser
reinstalar/atualizar uma parte específica sem mexer na outra, ou testar
o programa via linha de comando sem ele aparecer na ES.

O que instala (num passo só)
------------------------------
Parte 1 - o programa (/userdata/system/.dev/apps/pcsx2x6/):
  - runtime do pcsx2x6 (extraído do AppImage oficial v0.2.22)
  - wrapper de linha de comando + o helper "presskey" (/dev/uinput)
  - datapath com BIOS (System 246+256), todos os binds JVS de
    controle já configurados (Tekken, Soul Calibur, Bloody Roar,
    Gundam VS, Fate, Kinnikuman, Pride GP, Sengoku Basara, Super
    Dragon Ball Z, YuYu Hakusho, esquema Capcom 6 botões, Racing/
    Lightgun), hotkeys de save state (F1/F3) e BIOS pré-selecionado
    ([Filenames] BIOS=r27v1602f.7d)

Parte 2 - integração com EmulationStation/configgen:
  - generator Python registrado, evmapy, configgen-defaults.yml,
    es_systems.cfg e es_features.cfg todos ajustados (idempotente -
    pode rodar de novo sem duplicar nada)
  - opções extras nas "Opções Avançadas do Jogo" (troque EMULADOR
    pra "PCSX2X6"): PROPORÇÃO DE ASPECTO DO JOGO (preenche a tela,
    sem barras pretas) e PULAR APRESENTAÇÃO (carrega Slot 1
    automaticamente se existir, pulando BIOS/copyright/dongle)
  - wrapper /usr/bin/pcsx2x6, BIOS semeado no datapath da integração
  - persiste tudo em /usr no final (batocera-save-overlay, tamanho
    calculado a partir do uso real do overlay)

NÃO instala jogos/ROMs de propósito - migre-os separadamente pra
/userdata/roms/namco2x6/ (ver a memória do projeto pro formato .zip
ou .2x6).

Rodar de novo (atualização) preserva sempre o que já existe: o
datapath do programa (config/BIOS/saves) só é semeado se ainda não
existir, e os patches de config da EmulationStation são idempotentes
(detectam se já foram aplicados e pulam).

Uso
---
    bash install-pcsx2x6-full.sh
    # (roda como root na própria Batocera, com o .squashfs na mesma pasta)

Origem deste pacote
--------------------
Montado em 2026-09-13 fundindo os dois pacotes já verificados
byte-a-byte contra a máquina de teste 192.168.18.4 (ver os info.txt
de pcsx2x6-standalone/ e pcsx2x6-es-integration/ pros detalhes da
verificação e o histórico do recurso de boot-skip). O script foi
checado sintaticamente (bash -n + compile dos blocos Python
embutidos) mas o teste ao vivo de ponta a ponta deste instalador
COMBINADO específico ainda não rodou - a máquina 192.168.18.4 ficou
inacessível via SSH (porta 22 recusando conexão, apesar de responder
ping) bem na hora de testar. Recomendo rodar este instalador uma vez
lá assim que a máquina voltar, antes de considerar 100% validado -
o conteúdo é idêntico ao dos dois pacotes separados (já validados
individualmente), só a costura do script novo não foi exercitada de
ponta a ponta ainda.

Catálogo de jogos (referência)
-------------------------------
.
