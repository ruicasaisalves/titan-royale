# Titan Royale — esqueleto Godot 4

Auto-battle / battle royale 2D: controlas 1 lutador entre 99 IA, sobrevives
até ao top 6, e os sobreviventes viram **titãs ×10** numa arena diferente.
Inclui 7 classes (com Necromante e Sacerdote), zombies com lealdade, e itens.

## Como correr
1. Instala o **Godot 4.2 ou superior** (https://godotengine.org).
2. Abre o Godot → *Import* → escolhe a pasta `titan-royale` (o `project.godot`).
3. Carrega em **Play (F5)**.

Controlos: **WASD/setas** mover · **espaço** atacar · **shift** dash · também
podes **arrastar o rato** para te moveres.

> Nota: este projeto foi escrito sem correr o editor, por isso pode pedir um
> ou dois pequenos ajustes ao abrir. A estrutura é que é o valor.

## Arquitetura (porquê está assim)

O objetivo do desenho é permitir **multiplayer no futuro sem reescrever o jogo**.

- **Controladores → Intent → Simulação.** Um `Fighter` nunca decide nada
  sozinho. A cada tick, o seu `Controller` devolve uma `Intent` (mover / atacar
  / dash) e a `Arena` aplica-a de forma idêntica. Existem:
  - `AIController` — decide sozinho (alvo mais próximo).
  - `PlayerController` — lê o teclado/rato.
  - *(futuro)* `RemoteController` — lê a intent recebida pela rede.
  Adicionar online = criar esse terceiro controlador e trocar o `controller`
  do lutador. A simulação não muda.

- **Simulação autoritária e de passo fixo.** Tudo corre em
  `Arena._physics_process` (60 Hz fixo), numa ordem determinista
  (decidir → mover → separar → atacar → regen → fases). É a base certa para,
  mais tarde, a simulação correr num **servidor** e os clientes só enviarem
  Intents e desenharem o resultado.

- **Equipas / lealdade.** Cada lutador tem um `team`. Os zombies herdam o
  `team` do necromante, por isso lutam por ele e nunca o atacam. Quem pode
  vencer/virar titã é marcado com `contender = true` (zombies são `false`).

- **Grelha espacial** (`SpatialGrid`) para procurar vizinhos sem comparar
  todos-com-todos — é o que te deixa passar dos 100 para as centenas.

## Ficheiros
```
project.godot            configuração (cena principal, autoload, janela)
scenes/Main.tscn         cena raiz
scripts/
  Archetypes.gd          (autoload "Arch") definição das 7 classes
  Intent.gd              a intenção de um lutador num tick
  Controller.gd          base dos controladores
  AIController.gd        IA (alvo mais próximo via grelha)
  PlayerController.gd    input local -> Intent
  SpatialGrid.gd         particionamento espacial
  Fighter.gd             estado + desenho de um lutador
  Item.gd                pickups (armas / armadura / amuletos)
  Arena.gd               a simulação: tick, combate, itens, fases, titãs
  Main.gd                UI (criação + HUD) e ligação de tudo
```

## Controlos táteis (Android)
Em ecrãs de toque aparecem automaticamente um **joystick** (esquerda) e os
botões **ATACAR** / **DASH** (direita). São multi-touch a sério — cada widget
segue o *seu* dedo pelo índice de toque — por isso podes mover e atacar ao
mesmo tempo. Para os testar no PC com o rato, põe `FORCE_ON_DESKTOP = true`
em `scripts/TouchInput.gd`.

Ficheiros: `TouchInput.gd` (autoload `Touch`, estado partilhado),
`HudJoystick.gd`, `HudTouchButton.gd`. O `PlayerController` junta teclado,
rato e toque numa única `Intent` — a simulação não sabe de onde veio o input.

## Exportar para Android (passos)
1. **Editor → Manage Export Templates** → *Download and Install* (os templates
   têm de ser da **mesma versão** do editor).
2. Instala o **JDK 17** (o Godot 4 exige o 17 — com o 21 dá erro) e o
   **Android SDK** (command-line tools). No Godot: *Editor → Editor Settings →
   Export → Android* e aponta o *Java SDK Path* e o *Android SDK Path*.
3. Cria um **keystore** de debug (*Editor Settings → Export → Android →
   Debug Keystore*) — para testar no teu telemóvel chega.
4. **Project → Export → Add… → Android**, exporta um **APK** e instala-o no
   telemóvel (`adb install` ou copiar o ficheiro).
5. Para a Google Play: keystore de *release*, exportar **AAB**, e conta de
   programador (25 USD, uma vez).

Se o export aparecer cinzento ou der um erro de Gradle, é quase sempre
uma das três versões desalinhadas: editor, templates ou JDK.

## Próximos passos sugeridos
- Dar aos ranged (Arqueiro/Necromante) um **projétil** real em vez de golpe instantâneo.
- Sprites/animações: trocar o `_draw()` do `Fighter` por um `AnimatedSprite2D`.
- Desenhar a UI no editor com um tema próprio (a atual é funcional mas crua).
- Multiplayer: `RemoteController` + `ENetMultiplayerPeer` (ou Steamworks/Nakama),
  com a Arena a correr no servidor.
