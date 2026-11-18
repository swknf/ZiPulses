#!/usr/bin/env bash
# Compile le micrologiciel ZiPulses (cible PulsesSensor_OM15082, sans NTAG ni OTA, comme LiXee)
# avec la chaîne de MCUXpresso IDE installée sur le poste (testé avec 25.6.136, GCC 14.2).
# Usage (Git Bash) : outils/compiler.sh [--traces] [nom-de-sortie]
#   Un seul micrologiciel (4000-13U1) : le mode d'alimentation (pile ou secteur) se règle depuis
#   zigbee2mqtt (attribut BatterySize), plus de variante à la compilation.
#   --traces : binaire de banc 4000-13D1 avec traces série (115 200 bauds). Sur pile, chaque trace
#              tient le processeur éveillé (UART en attente active) : à réserver aux essais.
# Résultat : sorties/<nom>.bin (dossier ignoré par Git). Les fichiers suivis que la compilation
# réécrit (Binaries/, fichiers générés pdum_gen/zps_gen, data.bin, Doc/size.txt) sont remis en état.
set -euo pipefail
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
IDE="${MCUX_IDE:-$(ls -d /c/NXP/MCUXpressoIDE_* | sort -V | tail -1)}"
T="$(ls -d "$IDE"/ide/plugins/com.nxp.mcuxpresso.tools.win32_* | sort -V | tail -1)"
export PATH="$T/tools/bin:$T/buildtools/bin:$PATH"
# Éditeur de liens récent : avertissement « LOAD segment with RWX permissions » sans objet
# (pas de protection mémoire sur le JN5189). Option inconnue de l'ancien compilateur de LiXee.
export LDFLAGS="-Wl,--no-warn-rwx-segments"
# Plus aucune option de tolérance nécessaire : le code compile sans avertissement avec GCC 14.
export CFLAGS=""
VARIANTE=unique
TRACES=0
if [ "${1:-}" = "--traces" ]; then
  VARIANTE=banc; TRACES=1; CFLAGS="$CFLAGS -DZIPULSES_TRACES"; shift
fi
if [ "$TRACES" = 0 ]; then
  # Sans traces : DBG_vPrintf retirés (TRACE=0) et PRINTF des pilotes aussi (console du SDK désactivée)
  CFLAGS="$CFLAGS -DSDK_DEBUGCONSOLE=2"
fi
NOM="${1:-ZiPulses-$VARIANTE-$(git -C "$RACINE" rev-parse --short HEAD)}"
cd "$RACINE/PulsesSensor/Build/mcux"
# Compilation complète (-B : les .o suivis par Git, remis en place, ne doivent jamais être réutilisés)
# et séquentielle (en parallèle, les fichiers générés ne sont pas prêts à temps).
make -r -B TRACE=$TRACES TOOLCHAIN_DIR_PATH="$(cygpath -m "$T/tools")" APP_NTAG_ICODE=0 OTA=0 > "$RACINE/sorties.log" 2>&1 \
  || { tail -30 "$RACINE/sorties.log"; exit 1; }
mkdir -p "$RACINE/sorties"
BIN="$RACINE/Binaries/PulsesSensor_OM15082/PulsesSensor_OM15082.bin"
cp "$BIN" "$RACINE/sorties/$NOM.bin"
cp "$RACINE/Binaries/PulsesSensor_OM15082/PulsesSensor_OM15082.axf" "$RACINE/sorties/$NOM.axf"
mv "$RACINE/sorties.log" "$RACINE/sorties/$NOM.log"
cd "$RACINE"
git checkout -q -- Binaries PulsesSensor/Source/pdum_gen.c PulsesSensor/Source/pdum_gen.h \
  PulsesSensor/Source/zps_gen.c PulsesSensor/Source/zps_gen.h PulsesSensor/Build/mcux/data.bin Doc 2>/dev/null || true
git clean -q -f -- Binaries/PulsesSensor_OM15082/PulsesSensor_OM15082.bin
echo "Version annoncée : $(grep -a -o '4000-[0-9A-Za-z-]*' "sorties/$NOM.bin" | sort -u | tr '\n' ' ')"
echo "Traces : $([ "$TRACES" = 1 ] && echo oui || echo non)"
echo "Avertissements : $(grep -c 'warning:' "sorties/$NOM.log")"
ls -l "sorties/$NOM.bin"
