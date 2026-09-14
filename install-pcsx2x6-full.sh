#!/bin/bash
# Instala o pcsx2x6 (Namco System 246/256, https://github.com/PS2Homebrew-arcade/pcsx2x6)
# Modificações: Jeverson D. da Silva

set -e

if [ "$(id -u)" != "0" ]; then
	echo "Precisa rodar como root (ex.: via SSH root@<ip da batocera>)." >&2
	exit 1
fi

URL=https://github.com/JeversonDiasSilva/batocera-pcsx2x6/releases/download/v1.0/pcsx2x6-full-pkg.squashfs
WORKDIR=/userdata/system/.cache/pcsx2x6
mkdir -p "$WORKDIR"

PKG="${1:-$WORKDIR/pcsx2x6-full-pkg.squashfs}"
if [ ! -f "$PKG" ]; then
	echo "Baixando pacote em $PKG..."
	wget -O "$PKG" "$URL" || { rm -f "$PKG"; echo "Download falhou." >&2; exit 1; }
else
	echo "Usando pacote já baixado: $PKG"
fi
if [ "$(head -c 4 "$PKG")" != "hsqs" ]; then
	echo "O arquivo não é um squashfs válido (download corrompido?). Apague $PKG e rode de novo." >&2
	exit 1
fi

MNT="$(mktemp -d /tmp/pcsx2x6-full-install.XXXXXX)"
cleanup() { umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

echo "Montando $PKG..."
mount -o loop,ro "$PKG" "$MNT"

#############################################
# PARTE 1: o programa standalone (/userdata)
#############################################
DEST=/userdata/system/.dev/apps/pcsx2x6
mkdir -p "$DEST"

echo
echo "== Parte 1/2: instalando o programa em $DEST =="
echo "Instalando/atualizando runtime/evmapy/wrapper/presskey..."
rm -rf "$DEST/runtime" "$DEST/evmapy"
cp -a "$MNT/standalone/runtime" "$DEST/runtime"
mkdir -p "$DEST/evmapy"
cp "$MNT/shared/evmapy/namco2x6.pcsx2x6.keys" "$DEST/evmapy/namco2x6.pcsx2x6.keys"
cp "$MNT/standalone/pcsx2x6" "$DEST/pcsx2x6"
chmod +x "$DEST/pcsx2x6"
cp "$MNT/standalone/presskey" "$DEST/presskey"
chmod +x "$DEST/presskey"

if [ -d "$DEST/data" ]; then
	echo "$DEST/data já existe - preservando configuração/BIOS/saves atuais (não mexendo)."
else
	echo "Semeando datapath novo em $DEST/data (BIOS + PCSX2.ini com os controles já configurados)..."
	cp -a "$MNT/standalone/data-template" "$DEST/data"
fi

if ldd "$DEST/runtime/bin/pcsx2-qt" 2>&1 | grep -q "not found"; then
	echo "Aviso: alguma lib do sistema não foi encontrada (fora as bundladas em runtime/lib):" >&2
	ldd "$DEST/runtime/bin/pcsx2-qt" 2>&1 | grep "not found" >&2
else
	echo "OK - binário presente e todas as libs do sistema resolvidas."
fi
[ -f "$DEST/data/PCSX2x6/inis/PCSX2.ini" ] && echo "OK - PCSX2.ini presente com os binds JVS pré-configurados."
[ -f "$DEST/data/PCSX2x6/bios/r27v1602f.7d" ] && [ -f "$DEST/data/PCSX2x6/bios/r27v1602f.8g" ] && echo "OK - BIOS (System 246 + 256) presente."
[ -x "$DEST/presskey" ] && echo "OK - presskey presente (usado pelo boot-skip da integração ES abaixo)."

#####################################################
# PARTE 2: integração EmulationStation/configgen
#####################################################
echo
echo "== Parte 2/2: integrando com EmulationStation/configgen =="

CONFIGGEN_DIR="$(find /usr/lib -maxdepth 2 -iname 'python3.*' -type d 2>/dev/null | head -1)/site-packages/configgen"
if [ ! -d "$CONFIGGEN_DIR" ]; then
	echo "Não achei a pasta configgen (esperado /usr/lib/python3.X/site-packages/configgen) - versão do Batocera incompatível?" >&2
	exit 1
fi
GENIMPORTER="$CONFIGGEN_DIR/GeneratorImporter.py"
DEFAULTS_YML="$(find /usr/share -iname 'configgen-defaults.yml' 2>/dev/null | head -1)"
if [ ! -f "$GENIMPORTER" ] || [ -z "$DEFAULTS_YML" ]; then
	echo "Não achei GeneratorImporter.py ou configgen-defaults.yml." >&2
	exit 1
fi

echo "Instalando o generator em $CONFIGGEN_DIR/generators/pcsx2x6..."
rm -rf "$CONFIGGEN_DIR/generators/pcsx2x6"
cp -a "$MNT/esintegration/generators/pcsx2x6" "$CONFIGGEN_DIR/generators/pcsx2x6"

echo "Registrando 'pcsx2x6' em GeneratorImporter.py (idempotente)..."
python3 - "$GENIMPORTER" <<'EOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
if "emulator == 'pcsx2x6'" in content:
    print("  já registrado, pulando.")
else:
    marker = '    raise Exception(f"no generator found for emulator {emulator}")'
    snippet = ("    if emulator == 'pcsx2x6':\n"
               "        from generators.pcsx2x6.pcsx2x6Generator import Pcsx2x6Generator\n"
               "        return Pcsx2x6Generator()\n\n")
    assert marker in content, "marker not found in GeneratorImporter.py - versão incompatível?"
    content = content.replace(marker, snippet + marker, 1)
    with open(path, 'w') as f:
        f.write(content)
    print("  registrado.")
EOF

echo "Copiando evmapy (namco2x6.pcsx2x6.keys)..."
cp "$MNT/shared/evmapy/namco2x6.pcsx2x6.keys" /usr/share/evmapy/namco2x6.pcsx2x6.keys

FEATURES_CFG="$(find /usr/share/emulationstation -iname 'es_features.cfg' 2>/dev/null | head -1)"
if [ -n "$FEATURES_CFG" ]; then
	echo "Registrando as opções (PROPORÇÃO DE ASPECTO / PULAR APRESENTAÇÃO) em es_features.cfg (idempotente)..."
	python3 - "$FEATURES_CFG" "$MNT/esintegration/es-features-block.xml" <<'EOF'
import sys
cfg_path, block_path = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    content = f.read()
if 'emulator name="pcsx2x6"' in content:
    print("  já registrado, pulando.")
else:
    with open(block_path) as f:
        block = f.read()
    marker = "</features>"
    idx = content.rfind(marker)
    assert idx != -1, "</features> não encontrado - versão incompatível?"
    content = content[:idx] + block + content[idx:]
    with open(cfg_path, 'w') as f:
        f.write(content)
    print("  registrado.")
EOF
else
	echo "Aviso: não achei es_features.cfg - pulando (as opções extras não vão aparecer na UI, mas o jogo funciona com os padrões do generator)." >&2
fi

SYSTEMS_CFG="$(find /usr/share/emulationstation -iname 'es_systems.cfg' 2>/dev/null | head -1)"
if [ -n "$SYSTEMS_CFG" ]; then
	echo "Registrando 'pcsx2x6' como emulador do sistema namco2x6 em es_systems.cfg (idempotente)..."
	python3 - "$SYSTEMS_CFG" <<'EOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

if re.search(r'<name>namco2x6</name>.*?emulator name="pcsx2x6"', content, re.DOTALL):
    print("  já registrado, pulando.")
else:
    def fix_block(m):
        block = m.group(0)
        block = re.sub(
            r'(<extension>)([^<]*)(</extension>)',
            lambda em: em.group(1) + em.group(2) + ('' if '.2x6' in em.group(2) else ' .2x6') + em.group(3),
            block, count=1)
        new_emulator = ('            <emulator name="pcsx2x6">\n'
                         '                <cores>\n'
                         '                    <core default="true">pcsx2x6</core>\n'
                         '                </cores>\n'
                         '            </emulator>\n'
                         '        </emulators>')
        assert '</emulators>' in block, "bloco <emulators> nao encontrado dentro do sistema namco2x6"
        return block.replace('</emulators>', new_emulator, 1)

    pattern = re.compile(r'<system>\s*<fullname>[^<]*</fullname>\s*<name>namco2x6</name>.*?</system>', re.DOTALL)
    new_content, n = pattern.subn(fix_block, content, count=1)
    assert n == 1, "bloco do sistema namco2x6 nao encontrado em es_systems.cfg - versao incompativel?"
    with open(path, 'w') as f:
        f.write(new_content)
    print("  registrado.")
EOF
else
	echo "Aviso: não achei es_systems.cfg - pulando (a UI vai continuar só oferecendo 'play' como emulador pro namco2x6)." >&2
fi

echo "Ajustando configgen-defaults.yml (namco2x6 -> pcsx2x6, idempotente)..."
python3 - "$DEFAULTS_YML" <<'EOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
new_content, n = re.subn(
    r'^(namco2x6:\n  emulator: ).*\n(  core:     ).*\n',
    r'\g<1>pcsx2x6\n\g<2>pcsx2x6\n',
    content, count=1, flags=re.MULTILINE)
if n == 0:
    print("  aviso: bloco 'namco2x6:' não encontrado ou já no formato esperado - confira manualmente.")
else:
    with open(path, 'w') as f:
        f.write(new_content)
    print("  ajustado.")
EOF

echo "Instalando wrapper /usr/bin/pcsx2x6 (aponta pro programa em /userdata, não duplica no overlay)..."
cat > /usr/bin/pcsx2x6 <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="$DEST/runtime/lib:\${LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$DEST/runtime/plugins"
exec "$DEST/runtime/bin/pcsx2-qt" "\$@"
EOF
chmod +x /usr/bin/pcsx2x6

DATAPATH=/userdata/system/configs/pcsx2x6/PCSX2x6
echo "Semeando BIOS em $DATAPATH/bios (se ainda não existir)..."
mkdir -p "$DATAPATH/bios"
for f in r27v1602f.7d r27v1602f.8g r27v1602f.mec r27v1602f.nvm; do
	if [ ! -f "$DATAPATH/bios/$f" ]; then
		cp "$MNT/esintegration/bios/$f" "$DATAPATH/bios/$f"
	fi
done

echo
echo "Testando..."
[ -f "$CONFIGGEN_DIR/generators/pcsx2x6/pcsx2x6Generator.py" ] && echo "OK - generator instalado."
grep -q "emulator == 'pcsx2x6'" "$GENIMPORTER" && echo "OK - GeneratorImporter registrado."
grep -A1 '^namco2x6:' "$DEFAULTS_YML" | grep -q pcsx2x6 && echo "OK - configgen-defaults.yml aponta pra pcsx2x6."
[ -x /usr/bin/pcsx2x6 ] && echo "OK - /usr/bin/pcsx2x6 instalado."
[ -f "$DATAPATH/bios/r27v1602f.7d" ] && [ -f "$DATAPATH/bios/r27v1602f.8g" ] && echo "OK - BIOS presente no datapath da integração ES."
[ -n "$FEATURES_CFG" ] && grep -q 'emulator name="pcsx2x6"' "$FEATURES_CFG" && echo "OK - opções extras registradas em es_features.cfg."
[ -n "$SYSTEMS_CFG" ] && grep -q 'emulator name="pcsx2x6"' "$SYSTEMS_CFG" && echo "OK - pcsx2x6 registrado como emulador do namco2x6 em es_systems.cfg."

echo
echo "Persistindo as mudanças em /usr (RAM overlay - sem isso, some no próximo reboot)..."
OVERLAY_USED_KB=$(df --output=used / | tail -1)
OVERLAY_SIZE_MB=$(( OVERLAY_USED_KB * 13 / 10 / 1024 + 10 ))
echo "  (uso atual do overlay: $((OVERLAY_USED_KB/1024))MB - salvando com ${OVERLAY_SIZE_MB}MB)"
batocera-save-overlay "$OVERLAY_SIZE_MB"

echo
echo "=========================================================="
echo "Pronto! Instalação completa (programa + integração ES)."
echo "Reinicie a EmulationStation (ou rode"
echo "'batocera-es-swissknife --restart') pra ela re-escanear e"
echo "mostrar o sistema 'Namco System 246/256'."
echo
echo "Coloque jogos em /userdata/roms/namco2x6/ (.zip com o .acgame"
echo "+ subpasta com iso/elf/dongle dentro, OU .2x6 já pré-empacotado)"
echo "e o jogo aparece na lista normalmente."
echo
echo "Nota sobre 'OPÇÕES AVANÇADAS DO JOGO': com o campo EMULADOR em"
echo "'Automático' a tela só mostra as opções genéricas (energia, TDP,"
echo "vídeo, molduras) - troque o EMULADOR pra 'PCSX2X6' explicitamente"
echo "pra ver PROPORÇÃO DE ASPECTO e PULAR APRESENTAÇÃO."
echo
echo "Pacote em cache: $PKG"
echo "(apague se quiser liberar espaço ou forçar novo download)"
echo "=========================================================="
